import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/services/supabase_sync.dart';

/// Shared cache for AI Scripture Scholar answers. A question answered once is
/// reused for every user asking the same thing — cutting repeat OpenAI calls
/// (the dominant variable cost at scale). Cache is keyed by a normalized
/// question + language, so wording/casing/punctuation differences still hit.
class QaCacheService {
  String _key(String question, AppLanguage lang) {
    final norm = question
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
    return '${lang.code}:$norm';
  }

  // Returns {'text': ..., 'citations': [...]} on a hit, or null on a miss.
  Future<Map<String, dynamic>?> get(String question, AppLanguage lang) async {
    final client = SupabaseSync.client;
    if (client == null) return null;
    try {
      final row = await client
          .from('qa_cache')
          .select('response,citations')
          .eq('question_key', _key(question, lang))
          .maybeSingle();
      if (row == null) return null;
      final citations = (row['citations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      return {'text': row['response'] as String, 'citations': citations};
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String question, AppLanguage lang, Map<String, dynamic> result) async {
    final client = SupabaseSync.client;
    if (client == null) return;
    final text = result['text'] as String? ?? '';
    // Never cache empty or error responses.
    if (text.isEmpty || text.startsWith('⚠️')) return;
    try {
      await client.from('qa_cache').upsert({
        'question_key': _key(question, lang),
        'question': question,
        'language': lang.code,
        'response': text,
        'citations': result['citations'] ?? <String>[],
      }, onConflict: 'question_key');
    } catch (_) {
      // Non-blocking — caching is best-effort.
    }
  }
}
