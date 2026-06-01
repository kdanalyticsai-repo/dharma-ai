// ─────────────────────────────────────────────────────────────────────────
//  Import the Sanskrit Vedas (Rigveda, Shukla Yajurveda, Atharvaveda) into
//  the Supabase `verses` table.
//
//  Source: github.com/bhavykhatri/DharmicData (open-source, Sanskrit text
//  only). English translations are marked "coming soon" — these can be
//  filled in later (e.g. via a translation pass) without re-importing.
//
//  Prereqs: same as import_gita.mjs (verses table + Node 18+ + service key).
//  Run (PowerShell):
//   $env:SUPABASE_URL  = "https://YOUR-PROJECT.supabase.co"
//   $env:SUPABASE_SERVICE_KEY = "eyJ...service_role..."
//   node tools/import_vedas.mjs
// ─────────────────────────────────────────────────────────────────────────

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('❌ Set SUPABASE_URL and SUPABASE_SERVICE_KEY env vars first.');
  process.exit(1);
}

const RAW = 'https://raw.githubusercontent.com/bhavykhatri/DharmicData/main';
const NOTE = 'English translation coming soon.';

async function getJson(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`Fetch failed ${r.status} for ${url}`);
  return r.json();
}

const mk = (id, book, chapter, verse, text) => ({
  id,
  bookName: book,
  chapter: Number(chapter) || 0,
  verseNumber: Number(verse) || 0,
  sanskritText: (text || '').trim(),
  englishTransliteration: '',
  translation: NOTE,
  commentary: '',
  wordMeanings: null,
});

async function buildRows() {
  const rows = [];

  // Rigveda — 10 mandalas, records per sukta
  for (let m = 1; m <= 10; m++) {
    const arr = await getJson(`${RAW}/Rigveda/rigveda_mandala_${m}.json`);
    for (const r of arr) rows.push(mk(`RV_${r.mandala}_${r.sukta}`, 'Rig Veda', r.mandala, r.sukta, r.text));
  }

  // Atharvaveda — 20 kaandas, records per sukta
  for (let k = 1; k <= 20; k++) {
    const arr = await getJson(`${RAW}/AtharvaVeda/atharvaveda_kaanda_${k}.json`);
    for (const r of arr) rows.push(mk(`AV_${r.kaanda}_${r.sukta}`, 'Atharva Veda', r.kaanda, r.sukta, r.text));
  }

  // Shukla Yajurveda (Madhyandina samhita) — 40 adhyayas
  const yv = await getJson(`${RAW}/Yajurveda/vajasneyi_madhyadina_samhita.json`);
  for (const r of yv) rows.push(mk(`YV_${r.adhyaya}`, 'Yajur Veda', r.adhyaya, 1, r.text));

  return rows;
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
  console.log('⬇️  Downloading Veda datasets (DharmicData)…');
  const rows = await buildRows();
  console.log(`⬆️  Upserting ${rows.length} Veda records to Supabase…`);
  const BATCH = 100;
  for (let i = 0; i < rows.length; i += BATCH) {
    await upsertBatch(rows.slice(i, i + BATCH));
    console.log(`   ${Math.min(i + BATCH, rows.length)}/${rows.length}`);
  }
  console.log('✅ Done. Rig, Yajur & Atharva Veda (Sanskrit) are in the verses table.');
}

main().catch((e) => {
  console.error('❌', e.message);
  process.exit(1);
});
