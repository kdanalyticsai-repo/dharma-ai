import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/services/mock_scripture_data.dart';

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

  // Fetch all available verses
  Future<List<Verse>> getVerses() async {
    try {
      if (_supabase != null) {
        // If Supabase is set up, attempt database retrieval
        final response = await _supabase!
            .from('verses')
            .select()
            .order('chapter', ascending: true)
            .order('verseNumber', ascending: true);
        
        return (response as List)
            .map((item) => Verse.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Supabase scripture load failed, falling back to local mocks: $e');
    }

    // Default local fallback
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate networking delay
    return MockScriptureData.gitaVerses;
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

  // Get saved bookmark IDs
  Future<List<String>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_bookmarksKey) ?? [];
  }

  // Toggle bookmark state
  Future<bool> toggleBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_bookmarksKey) ?? [];
    bool isBookmarked;
    
    if (current.contains(id)) {
      current.remove(id);
      isBookmarked = false;
    } else {
      current.add(id);
      isBookmarked = true;
    }
    
    await prefs.setStringList(_bookmarksKey, current);
    return isBookmarked;
  }
}
