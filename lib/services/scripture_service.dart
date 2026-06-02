import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/services/mock_scripture_data.dart';
import 'package:dharma_ai/services/supabase_sync.dart';

class ScriptureService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Key for local bookmarks list in SharedPreferences
  static const String _bookmarksKey = 'dharma_bookmarks';

  // Fetch all Bhagavad Gita verses (the Gita reader, feed daily verse and
  // bookmark resolution use this — Vedas/Upanishads are fetched separately).
  Future<List<Verse>> getVerses() async {
    try {
      if (_supabase != null) {
        final response = await _supabase!
            .from('verses')
            .select()
            .eq('bookName', 'Bhagavad Gita')
            .order('chapter', ascending: true)
            .order('verseNumber', ascending: true);

        final list = (response as List)
            .map((item) => Verse.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      print('Supabase scripture load failed, falling back to local mocks: $e');
    }

    await Future.delayed(const Duration(milliseconds: 200));
    return MockScriptureData.gitaVerses;
  }

  // Fetch one Veda (Rig / Yajur / Atharva) by name. Queries per-book with a
  // high limit so large Vedas (Rigveda ~1028) aren't truncated by the default
  // row cap. Falls back to the curated samples for that book.
  Future<List<Verse>> getVedaVersesByBook(String book) async {
    try {
      if (_supabase != null) {
        final response = await _supabase!
            .from('verses')
            .select()
            .eq('bookName', book)
            .order('chapter', ascending: true)
            .order('verseNumber', ascending: true)
            .limit(2000);

        final list = (response as List)
            .map((item) => Verse.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      print('Supabase Veda load failed for $book, falling back to samples: $e');
    }
    return MockScriptureData.vedaVerses.where((v) => v.bookName == book).toList();
  }

  // Fetch single verse by ID
  Future<Verse?> getVerseById(String id) async {
    try {
      if (_supabase != null) {
        final response = await _supabase!
            .from('verses')
            .select()
            .eq('id', id)
            .single();
        return Verse.fromJson(response as Map<String, dynamic>);
      }
    } catch (e) {
      print('Supabase verse lookup failed for $id, searching local: $e');
    }

    // Local fallback
    try {
      return MockScriptureData.gitaVerses.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  // Resolve verses by id across all books. Merges Supabase results with the
  // local samples so ids that only exist locally (e.g. Upanishad samples)
  // are still found. Preserves the order of the requested ids.
  Future<List<Verse>> getVersesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final found = <String, Verse>{};

    try {
      if (_supabase != null) {
        final response = await _supabase!.from('verses').select().inFilter('id', ids);
        for (final item in (response as List)) {
          final v = Verse.fromJson(item as Map<String, dynamic>);
          found[v.id] = v;
        }
      }
    } catch (e) {
      print('Supabase verses-by-id failed, using local: $e');
    }

    // Fill any ids not found in Supabase from the bundled samples.
    final missing = ids.where((id) => !found.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      final all = [
        ...MockScriptureData.gitaVerses,
        ...MockScriptureData.upanishadVerses,
        ...MockScriptureData.vedaVerses,
      ];
      for (final v in all) {
        if (missing.contains(v.id)) found[v.id] = v;
      }
    }

    return ids.where(found.containsKey).map((id) => found[id]!).toList();
  }

  // Keyword search on scriptures
  Future<List<Verse>> searchScriptures(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      if (_supabase != null) {
        // Simple text search or semantic vector search (we fall back on keyword search here)
        final response = await _supabase!
            .from('verses')
            .select()
            .or('translation.ilike.%$query%,commentary.ilike.%$query%,sanskritText.ilike.%$query%');
        return (response as List)
            .map((item) => Verse.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Supabase search failed, checking local mocks: $e');
    }

    // Local search fallback
    await Future.delayed(const Duration(milliseconds: 300));
    final lowercaseQuery = query.toLowerCase();
    return MockScriptureData.gitaVerses.where((verse) {
      return verse.translation.toLowerCase().contains(lowercaseQuery) ||
          verse.commentary.toLowerCase().contains(lowercaseQuery) ||
          verse.englishTransliteration.toLowerCase().contains(lowercaseQuery) ||
          verse.sanskritText.contains(query);
    }).toList();
  }

  // Get saved bookmark IDs.
  // When signed in, the bookmarks table is authoritative (and is cached
  // locally); otherwise read from local storage.
  Future<List<String>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client != null && uid != null) {
      try {
        final rows = await client.from('bookmarks')
            .select('verse_id')
            .eq('user_id', uid);
        final ids = (rows as List)
            .map((r) => r['verse_id'] as String)
            .toList();
        await prefs.setStringList(_bookmarksKey, ids); // cache
        return ids;
      } catch (_) {
        // fall through to local
      }
    }
    return prefs.getStringList(_bookmarksKey) ?? [];
  }

  // Toggle bookmark state (persists to Supabase when signed in).
  Future<bool> toggleBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_bookmarksKey) ?? [];
    final bool isBookmarked = !current.contains(id);

    if (isBookmarked) {
      current.add(id);
    } else {
      current.remove(id);
    }
    await prefs.setStringList(_bookmarksKey, current);

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client != null && uid != null) {
      try {
        if (isBookmarked) {
          await client.from('bookmarks').upsert(
            {'user_id': uid, 'verse_id': id},
            onConflict: 'user_id,verse_id',
          );
        } else {
          await client.from('bookmarks')
              .delete().eq('user_id', uid).eq('verse_id', id);
        }
      } catch (_) {
        // Non-blocking — local cache already updated.
      }
    }
    return isBookmarked;
  }
}
