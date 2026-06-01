// ─────────────────────────────────────────────────────────────────────────
//  AI-assisted English translation pass for the Veda verses.
//
//  Finds verses still marked "English translation coming soon." and asks
//  OpenAI for a faithful English translation + short commentary, then writes
//  them back to the Supabase `verses` table. RESUMABLE — re-run any time; it
//  only processes rows that still need translating.
//
//  ⚠️  These are AI-assisted translations of Vedic Sanskrit — useful, but not
//  a substitute for scholarly editions. The app labels them accordingly.
//
//  Prereqs: Node 18+, the verses table populated by import_vedas.mjs.
//  Env vars:
//   $env:SUPABASE_URL          = "https://YOUR-PROJECT.supabase.co"
//   $env:SUPABASE_SERVICE_KEY  = "eyJ...service_role..."
//   $env:OPENAI_API_KEY        = "sk-..."
//   $env:TRANSLATE_LIMIT       = "10"   # optional: stop after N (test first!)
//   node tools/translate_vedas.mjs
// ─────────────────────────────────────────────────────────────────────────

const { SUPABASE_URL, SUPABASE_SERVICE_KEY, OPENAI_API_KEY } = process.env;
const LIMIT = parseInt(process.env.TRANSLATE_LIMIT || '0', 10); // 0 = all
const CONCURRENCY = parseInt(process.env.TRANSLATE_CONCURRENCY || '4', 10);
const PLACEHOLDER = 'English translation coming soon.';
const MODEL = 'gpt-4o-mini';

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY || !OPENAI_API_KEY) {
  console.error('❌ Set SUPABASE_URL, SUPABASE_SERVICE_KEY and OPENAI_API_KEY.');
  process.exit(1);
}

const sb = (path, init = {}) =>
  fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
  });

async function fetchPending(pageSize) {
  // All placeholder rows are Vedas (Gita already has real translations).
  const q =
    `verses?translation=eq.${encodeURIComponent(PLACEHOLDER)}` +
    `&select=id,"bookName",chapter,"verseNumber","sanskritText"&limit=${pageSize}`;
  const res = await sb(q);
  if (!res.ok) throw new Error(`Fetch pending failed ${res.status}: ${await res.text()}`);
  return res.json();
}

async function translate(row) {
  const prompt =
    `You are a careful translator of Vedic Sanskrit. Below is a hymn from the ` +
    `${row.bookName} (Chapter/Mandala ${row.chapter}, Sukta/Verse ${row.verseNumber}).\n\n` +
    `Sanskrit:\n${row.sanskritText}\n\n` +
    `Return ONLY JSON: {"translation": "...", "commentary": "..."}.\n` +
    `- translation: a faithful, readable English rendering (3-6 sentences).\n` +
    `- commentary: 1-2 sentences on the hymn's deity/theme and spiritual meaning.\n` +
    `Be reverent and accurate; do not invent specifics you are unsure of.`;

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      max_tokens: 500,
      response_format: { type: 'json_object' },
    }),
  });
  if (!res.ok) throw new Error(`OpenAI ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const parsed = JSON.parse(data.choices[0].message.content);
  return {
    translation: (parsed.translation || '').trim(),
    commentary: (parsed.commentary || '').trim(),
  };
}

async function save(id, t) {
  const res = await sb(`verses?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({ translation: t.translation, commentary: t.commentary }),
  });
  if (!res.ok) throw new Error(`Save ${id} failed ${res.status}: ${await res.text()}`);
}

async function main() {
  let done = 0;
  for (;;) {
    const want = LIMIT ? Math.min(CONCURRENCY, LIMIT - done) : CONCURRENCY;
    if (want <= 0) break;
    const batch = await fetchPending(want);
    if (batch.length === 0) break;

    await Promise.all(
      batch.map(async (row) => {
        try {
          const t = await translate(row);
          if (t.translation) {
            await save(row.id, t);
            done++;
            console.log(`✓ ${row.id}`);
          } else {
            console.warn(`… ${row.id} (empty translation, skipped)`);
          }
        } catch (e) {
          console.error(`✗ ${row.id}: ${e.message}`);
        }
      })
    );
    console.log(`   — translated ${done} so far —`);
    if (LIMIT && done >= LIMIT) break;
  }
  console.log(`✅ Finished. Translated ${done} Veda verses this run.`);
  console.log('   Re-run to continue; it resumes where it left off.');
}

main().catch((e) => {
  console.error('❌', e.message);
  process.exit(1);
});
