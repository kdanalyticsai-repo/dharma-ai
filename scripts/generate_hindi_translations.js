#!/usr/bin/env node
/**
 * generate_hindi_translations.js
 *
 * Fetches all verses from Supabase (Gita + Vedas + Upanishads) that don't yet
 * have a Hindi translation, calls OpenAI gpt-4o-mini to generate one, then
 * writes it back to the `verses` table in the `hindiTranslation` column.
 *
 * Prerequisites:
 *   cd scripts && npm install @supabase/supabase-js openai
 *
 * Run (from scripts/ folder):
 *   $env:SUPABASE_SERVICE_KEY = "eyJ..."   # service_role key (NOT anon key)
 *   $env:OPENAI_API_KEY = "sk-proj-..."
 *   node generate_hindi_translations.js
 *
 * The script is RESUMABLE: rows with hindiTranslation already set are skipped.
 */

const { createClient } = require('@supabase/supabase-js');
const OpenAI = require('openai');

// ── Config ────────────────────────────────────────────────────────────────────
const SUPABASE_URL         = process.env.SUPABASE_URL || 'https://fhzmhksukawpuoxssydn.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || '';
const OPENAI_API_KEY       = process.env.OPENAI_API_KEY || '';

const BATCH_SIZE = 50;
const DELAY_MS   = 350;  // ~3 req/sec — stays within OpenAI free-tier RPM
const MODEL      = 'gpt-4o-mini';

// ── Validate ──────────────────────────────────────────────────────────────────
if (!SUPABASE_SERVICE_KEY) {
  console.error('ERROR: SUPABASE_SERVICE_KEY not set.');
  console.error('Get it from: Supabase Dashboard → Project Settings → API → service_role secret');
  process.exit(1);
}
if (!OPENAI_API_KEY) {
  console.error('ERROR: OPENAI_API_KEY not set.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
const openai   = new OpenAI({ apiKey: OPENAI_API_KEY });

// ── Prompt ────────────────────────────────────────────────────────────────────
function buildPrompt(verse) {
  const source = verse.bookName === 'Bhagavad Gita'
    ? `Bhagavad Gita (Chapter ${verse.chapter}, Verse ${verse.verseNumber})`
    : `${verse.bookName} (Chapter ${verse.chapter}, Verse ${verse.verseNumber})`;

  return `You are a Sanskrit scholar and Hindi translator. Translate the following scripture verse into natural, flowing Hindi (Devanagari script). The translation should be faithful to the meaning, use simple modern Hindi (not archaic), and be 1–4 sentences. Return ONLY the Hindi translation — no English, no transliteration, no explanation.

Source: ${source}
Sanskrit: ${verse.sanskritText || '(not available)'}
English meaning: ${verse.translation}`;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  let offset = 0;
  let total  = 0;
  let done   = 0;
  let errors = 0;

  console.log('Fetching verses without Hindi translation...\n');

  while (true) {
    // PostgREST / Supabase JS: use plain camelCase column names (no SQL quotes)
    const { data: verses, error } = await supabase
      .from('verses')
      .select('id, bookName, chapter, verseNumber, sanskritText, translation')
      .is('hindiTranslation', null)
      .range(offset, offset + BATCH_SIZE - 1);

    if (error) {
      console.error('Supabase fetch error:', error.message);
      process.exit(1);
    }

    if (!verses || verses.length === 0) break;

    total += verses.length;
    console.log(`Processing batch at offset ${offset} (${verses.length} verses)...`);

    for (const verse of verses) {
      try {
        const prompt = buildPrompt(verse);

        const response = await openai.chat.completions.create({
          model: MODEL,
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 300,
          temperature: 0.3,
        });

        const hindiText = response.choices[0]?.message?.content?.trim();
        if (!hindiText) throw new Error('Empty response from OpenAI');

        // Plain camelCase key — Supabase JS client handles the quoting internally
        const { error: updateError } = await supabase
          .from('verses')
          .update({ hindiTranslation: hindiText })
          .eq('id', verse.id);

        if (updateError) throw new Error(`Supabase update error: ${updateError.message}`);

        done++;
        console.log(`  ✓ ${verse.id}  →  ${hindiText.slice(0, 60)}…`);

        await sleep(DELAY_MS);
      } catch (err) {
        errors++;
        console.error(`  ✗ ${verse.id}: ${err.message}`);
        await sleep(DELAY_MS);
      }
    }

    offset += BATCH_SIZE;
  }

  console.log(`\nDone. Translated: ${done}/${total}. Errors: ${errors}.`);
  if (errors > 0) {
    console.log('Re-run to retry failed verses (hindiTranslation is still null for them).');
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
