// ─────────────────────────────────────────────────────────────────────────
//  Import the full Bhagavad Gita (700 verses) into the Supabase `verses`
//  table.
//
//  Copyright posture (see app content audit):
//   • Sanskrit + transliteration  → ancient text, public domain.
//   • English translation         → Shri Purohit Swami (d.1941): public
//                                    domain in India (since 2002) and in all
//                                    life+70 countries (since 2012).
//   • Commentary                  → AI-generated (gpt-4o-mini) and therefore
//                                    your own content. No reliance on any
//                                    living publisher's text.
//  Data source: github.com/gita/gita (dataset dedicated under The Unlicense).
//
//  Prereqs:
//   1. Run the `verses` table DDL from supabase_schema.sql in the SQL editor.
//   2. Node 18+ (has global fetch). Check: node --version
//   3. Get your SERVICE ROLE key: Supabase → Settings → API → service_role
//      (secret — never commit it).
//   4. (Optional, for commentary) An OpenAI key. Without it the import still
//      runs but leaves the commentary field blank.
//
//  Run (PowerShell):
//   $env:SUPABASE_URL  = "https://YOUR-PROJECT.supabase.co"
//   $env:SUPABASE_SERVICE_KEY = "eyJ...service_role..."
//   $env:OPENAI_API_KEY = "sk-...."          # optional, enables commentary
//   node tools/import_gita.mjs
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

const RAW = 'https://raw.githubusercontent.com/gita/gita/main/data';
// Public-domain English translation (d.1941). Falls back to any English entry
// only if a verse is missing — the dataset covers all 701, so this shouldn't
// trigger; we warn if it ever does so we never silently ship copyrighted text.
const PREF_TRANSLATION = 'Shri Purohit Swami';

// Commentary is AI-generated (see generateCommentary). Cached to disk so
// re-runs don't re-pay the OpenAI cost.
const OPENAI_MODEL = 'gpt-4o-mini';
const COMMENTARY_CONCURRENCY = 6;
const __dirname = dirname(fileURLToPath(import.meta.url));
const CACHE_FILE = join(__dirname, '.gita_commentary_cache.json');

// Strip leading verse-number markers like "।।1.1।।" / "1.1" from text.
const clean = (s) =>
  (s || '').replace(/।।\s*\d+\.\d+\s*।।/g, '').replace(/^\s*\d+\.\d+\s*/, '').trim();

async function getJson(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`Fetch failed ${r.status} for ${url}`);
  return r.json();
}

function pickByVerse(rows, prefAuthor) {
  const map = {};
  for (const row of rows) {
    if (row.lang !== 'english') continue;
    const existing = map[row.verse_id];
    // Set if none yet, or upgrade to the preferred author.
    if (!existing || row.authorName === prefAuthor) {
      map[row.verse_id] = { text: row.description, author: row.authorName };
    }
  }
  return map;
}

// ── AI commentary ──────────────────────────────────────────────────────────
function loadCache() {
  if (!existsSync(CACHE_FILE)) return {};
  try { return JSON.parse(readFileSync(CACHE_FILE, 'utf8')); }
  catch { return {}; }
}
function saveCache(cache) {
  writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 0));
}

async function generateCommentary({ chapter, verse, sanskrit, translation }) {
  const sys =
    'You are a faithful scholar of the Bhagavad Gita. Write a short, clear ' +
    'commentary (2–4 sentences) on the given verse: explain its meaning and ' +
    'one practical spiritual insight a seeker can apply. Stay grounded in the ' +
    'verse itself — do not invent quotes, Sanskrit, or facts, and do not push ' +
    'any one sect or school. Plain, warm prose. No headings or verse numbers.';
  const user =
    `Bhagavad Gita ${chapter}.${verse}\n` +
    `Sanskrit: ${sanskrit}\n` +
    `Translation (Shri Purohit Swami): ${translation}`;

  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      temperature: 0.4,
      max_tokens: 220,
      messages: [
        { role: 'system', content: sys },
        { role: 'user', content: user },
      ],
    }),
  });
  if (!r.ok) throw new Error(`OpenAI ${r.status}: ${await r.text()}`);
  const j = await r.json();
  return (j.choices?.[0]?.message?.content || '').trim();
}

// Generate commentary for all rows, with a small concurrency pool + disk cache.
async function buildCommentaries(rows) {
  if (!OPENAI_API_KEY) {
    console.warn('⚠️  OPENAI_API_KEY not set — importing with blank commentary.');
    return;
  }
  const cache = loadCache();
  const todo = rows.filter((r) => !cache[r.id]);
  console.log(`🧠 Commentary: ${rows.length - todo.length} cached, generating ${todo.length}…`);

  let done = 0, idx = 0;
  async function worker() {
    while (idx < todo.length) {
      const row = todo[idx++];
      try {
        cache[row.id] = await generateCommentary({
          chapter: row.chapter, verse: row.verseNumber,
          sanskrit: row.sanskritText, translation: row.translation,
        });
      } catch (e) {
        console.warn(`   ! ${row.id}: ${e.message} (will retry next run)`);
      }
      if (++done % 25 === 0) { saveCache(cache); console.log(`   ${done}/${todo.length}`); }
    }
  }
  await Promise.all(Array.from({ length: COMMENTARY_CONCURRENCY }, worker));
  saveCache(cache);

  for (const row of rows) row.commentary = clean(cache[row.id] || '');
  console.log('🧠 Commentary done.');
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
  console.log('⬇️  Downloading gita/gita datasets…');
  const [verses, translations] = await Promise.all([
    getJson(`${RAW}/verse.json`),
    getJson(`${RAW}/translation.json`),
  ]);
  console.log(`   verses=${verses.length} translations=${translations.length}`);

  const trans = pickByVerse(translations, PREF_TRANSLATION);

  // Safety net: never silently ship a non-public-domain translation.
  const fallbacks = verses.filter(
    (v) => trans[v.id] && trans[v.id].author !== PREF_TRANSLATION,
  );
  if (fallbacks.length) {
    console.warn(
      `⚠️  ${fallbacks.length} verse(s) lack a "${PREF_TRANSLATION}" translation ` +
      `and fell back to another author. Review before publishing:`,
    );
    for (const v of fallbacks.slice(0, 10)) {
      console.warn(`     BG ${v.chapter_number}.${v.verse_number} → ${trans[v.id].author}`);
    }
  }

  const rows = verses.map((v) => ({
    id: `BG_${v.chapter_number}_${v.verse_number}`,
    bookName: 'Bhagavad Gita',
    chapter: v.chapter_number,
    verseNumber: v.verse_number,
    sanskritText: clean(v.text),
    englishTransliteration: (v.transliteration || '').trim(),
    translation: clean(trans[v.id]?.text || ''),
    commentary: '', // filled by buildCommentaries (AI-generated)
    wordMeanings: null,
  }));

  // Generate the AI commentary (cached on disk) before upserting.
  await buildCommentaries(rows);

  console.log(`⬆️  Upserting ${rows.length} verses to Supabase…`);
  const BATCH = 100;
  for (let i = 0; i < rows.length; i += BATCH) {
    await upsertBatch(rows.slice(i, i + BATCH));
    console.log(`   ${Math.min(i + BATCH, rows.length)}/${rows.length}`);
  }
  console.log('✅ Done. Bhagavad Gita is now in the verses table.');
}

main().catch((e) => {
  console.error('❌', e.message);
  process.exit(1);
});
