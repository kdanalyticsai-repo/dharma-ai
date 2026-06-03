// ─────────────────────────────────────────────────────────────────────────
//  Import principal Upanishads into the Supabase `verses` table.
//
//  Copyright posture (see app content audit):
//   • Sanskrit verse text  → ancient, PUBLIC DOMAIN. We extract ONLY the
//     verse (sloka) text — never anyone's translation, commentary or notes.
//   • Transliteration / translation / commentary → AI-generated
//     (gpt-4o-mini) and therefore your own content.
//
//  We deliberately AVOID NonCommercial-licensed e-texts (e.g. GRETIL, which
//  is CC BY-NC-SA) — the NC clause is incompatible with a paid app. The verse
//  text itself is public domain regardless of who transcribed it; the source
//  below is used only to read that public-domain text accurately.
//
//  Sanskrit source: github.com/mananam/upanishads (verified, structured —
//  we read only the `content.sloka` field, i.e. the ancient verse).
//
//  Prereqs (PowerShell):
//   $env:SUPABASE_URL  = "https://YOUR-PROJECT.supabase.co"
//   $env:SUPABASE_SERVICE_KEY = "eyJ...service_role..."
//   $env:OPENAI_API_KEY = "sk-...."          # required for transliteration/
//                                            # translation/commentary
//   node tools/import_upanishads.mjs
// ─────────────────────────────────────────────────────────────────────────

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('❌ Set SUPABASE_URL and SUPABASE_SERVICE_KEY env vars first.');
  process.exit(1);
}
if (!OPENAI_API_KEY) {
  console.error('❌ Set OPENAI_API_KEY (needed for translation/commentary).');
  process.exit(1);
}

const OPENAI_MODEL = 'gpt-4o-mini';
const CONCURRENCY = 6;
const __dirname = dirname(fileURLToPath(import.meta.url));
const CACHE_FILE = join(__dirname, '.upanishad_cache.json');

// ── Sources ─────────────────────────────────────────────────────────────────
//  Each book lists its verified Sanskrit khandas (sections). To add another
//  Upanishad later, plug in a source whose verse text is public-domain and
//  whose transcription is NOT NonCommercial-licensed.
const KENA_RAW = 'https://raw.githubusercontent.com/mananam/upanishads/master/data/kena';
const SOURCES = [
  {
    book: 'Kena Upanishad',
    idPrefix: 'KENA',
    // mananam dir "001" is the śānti-pāṭha invocation; khandas are 002–005.
    khandas: [
      { dir: '002', chapter: 1, count: 8 },
      { dir: '003', chapter: 2, count: 5 },
      { dir: '004', chapter: 3, count: 12 },
      { dir: '005', chapter: 4, count: 9 },
    ],
    raw: KENA_RAW,
  },
];

// Strip trailing colophons like "॥ इति केनोपनिषदि प्रथमः खण्डः ॥" /
// "॥ सामवेदीय केनोपनिषद् समाप्तः ॥" so only the mantra remains.
function cleanSanskrit(s) {
  return (s || '')
    .replace(/॥[^॥]*(?:खण्ड|समाप्त)[^॥]*॥/g, '॥')
    .replace(/\s*॥(\s*॥)+/g, ' ॥')
    .replace(/\s+/g, ' ')
    .trim();
}

async function getJson(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`Fetch failed ${r.status} for ${url}`);
  return r.json();
}

// ── Read the public-domain verse text for every source ───────────────────────
async function collectVerses() {
  const rows = [];
  for (const src of SOURCES) {
    for (const k of src.khandas) {
      for (let v = 1; v <= k.count; v++) {
        const n = String(v).padStart(3, '0');
        const data = await getJson(`${src.raw}/${k.dir}/${n}.json`);
        const sanskrit = cleanSanskrit((data.content?.sloka || []).join(' '));
        if (!sanskrit) continue;
        rows.push({
          id: `${src.idPrefix}_${k.chapter}_${v}`,
          bookName: src.book,
          chapter: k.chapter,
          verseNumber: v,
          sanskritText: sanskrit,
          englishTransliteration: '',
          translation: '',
          commentary: '',
          wordMeanings: null,
        });
      }
    }
    console.log(`   ${src.book}: ${rows.filter((r) => r.bookName === src.book).length} mantras`);
  }
  return rows;
}

// ── AI: transliteration + translation + commentary in one call ───────────────
function loadCache() {
  if (!existsSync(CACHE_FILE)) return {};
  try { return JSON.parse(readFileSync(CACHE_FILE, 'utf8')); }
  catch { return {}; }
}
function saveCache(cache) { writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 0)); }

async function generate({ book, chapter, verse, sanskrit }) {
  const sys =
    'You are a faithful Sanskrit scholar of the Upanishads. Given a Devanagari ' +
    'verse, return strict JSON with three fields:\n' +
    '  "transliteration": accurate IAST transliteration of the verse,\n' +
    '  "translation": a clear, faithful English translation,\n' +
    '  "commentary": 2–4 sentences explaining the meaning and one practical ' +
    'spiritual insight.\n' +
    'Stay grounded in the verse — do not invent text, do not push any one sect. ' +
    'Plain, warm prose. Return ONLY the JSON object.';
  const user = `${book} ${chapter}.${verse}\nSanskrit (Devanagari): ${sanskrit}`;

  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      temperature: 0.4,
      max_tokens: 500,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: sys },
        { role: 'user', content: user },
      ],
    }),
  });
  if (!r.ok) throw new Error(`OpenAI ${r.status}: ${await r.text()}`);
  const j = await r.json();
  const obj = JSON.parse(j.choices?.[0]?.message?.content || '{}');
  return {
    transliteration: (obj.transliteration || '').trim(),
    translation: (obj.translation || '').trim(),
    commentary: (obj.commentary || '').trim(),
  };
}

async function enrich(rows) {
  const cache = loadCache();
  const todo = rows.filter((r) => !cache[r.id]);
  console.log(`🧠 ${rows.length - todo.length} cached, generating ${todo.length}…`);

  let done = 0, idx = 0;
  async function worker() {
    while (idx < todo.length) {
      const row = todo[idx++];
      try {
        cache[row.id] = await generate({
          book: row.bookName, chapter: row.chapter,
          verse: row.verseNumber, sanskrit: row.sanskritText,
        });
      } catch (e) {
        console.warn(`   ! ${row.id}: ${e.message} (retry next run)`);
      }
      if (++done % 10 === 0) { saveCache(cache); console.log(`   ${done}/${todo.length}`); }
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));
  saveCache(cache);

  for (const row of rows) {
    const c = cache[row.id];
    if (!c) continue;
    row.englishTransliteration = c.transliteration;
    row.translation = c.translation;
    row.commentary = c.commentary;
  }
  console.log('🧠 Enrichment done.');
}

async function upsertBatch(rows) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/verses`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify(rows),
  });
  if (!res.ok) throw new Error(`Upsert failed ${res.status}: ${await res.text()}`);
}

async function main() {
  console.log('⬇️  Reading public-domain Upanishad verse text…');
  const rows = await collectVerses();
  console.log(`   total ${rows.length} mantras`);

  await enrich(rows);

  // Don't ship rows that never got their translation (e.g. transient failures).
  const ready = rows.filter((r) => r.translation);
  if (ready.length < rows.length) {
    console.warn(`⚠️  ${rows.length - ready.length} mantra(s) missing translation — re-run to fill. Skipping them for now.`);
  }

  console.log(`⬆️  Upserting ${ready.length} verses to Supabase…`);
  const BATCH = 100;
  for (let i = 0; i < ready.length; i += BATCH) {
    await upsertBatch(ready.slice(i, i + BATCH));
    console.log(`   ${Math.min(i + BATCH, ready.length)}/${ready.length}`);
  }
  console.log('✅ Done. Upanishads are now in the verses table.');
}

main().catch((e) => {
  console.error('❌', e.message);
  process.exit(1);
});
