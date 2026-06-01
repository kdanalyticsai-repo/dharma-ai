// ─────────────────────────────────────────────────────────────────────────
//  Import the full Bhagavad Gita (700 verses) into the Supabase `verses`
//  table. Open-source data: github.com/gita/gita (permissive license).
//
//  Prereqs:
//   1. Run the `verses` table DDL from supabase_schema.sql in the SQL editor.
//   2. Node 18+ (has global fetch). Check: node --version
//   3. Get your SERVICE ROLE key: Supabase → Settings → API → service_role
//      (secret — never commit it).
//
//  Run (PowerShell):
//   $env:SUPABASE_URL  = "https://YOUR-PROJECT.supabase.co"
//   $env:SUPABASE_SERVICE_KEY = "eyJ...service_role..."
//   node tools/import_gita.mjs
// ─────────────────────────────────────────────────────────────────────────

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('❌ Set SUPABASE_URL and SUPABASE_SERVICE_KEY env vars first.');
  process.exit(1);
}

const RAW = 'https://raw.githubusercontent.com/gita/gita/main/data';
// Preferred English authors (fall back to any English entry if absent).
const PREF_TRANSLATION = 'Swami Sivananda';
const PREF_COMMENTARY = 'Swami Sivananda';

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
  const [verses, translations, commentaries] = await Promise.all([
    getJson(`${RAW}/verse.json`),
    getJson(`${RAW}/translation.json`),
    getJson(`${RAW}/commentary.json`),
  ]);
  console.log(`   verses=${verses.length} translations=${translations.length} commentaries=${commentaries.length}`);

  const trans = pickByVerse(translations, PREF_TRANSLATION);
  const comm = pickByVerse(commentaries, PREF_COMMENTARY);

  const rows = verses.map((v) => ({
    id: `BG_${v.chapter_number}_${v.verse_number}`,
    bookName: 'Bhagavad Gita',
    chapter: v.chapter_number,
    verseNumber: v.verse_number,
    sanskritText: clean(v.text),
    englishTransliteration: (v.transliteration || '').trim(),
    translation: clean(trans[v.id]?.text || ''),
    commentary: clean(comm[v.id]?.text || ''),
    wordMeanings: null,
  }));

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
