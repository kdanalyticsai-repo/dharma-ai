import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/services/scripture_service.dart';

// Service provider
final scriptureServiceProvider = Provider<ScriptureService>((ref) {
  return ScriptureService();
});

// All Bhagavad Gita verses
final versesProvider = FutureProvider<List<Verse>>((ref) async {
  final service = ref.watch(scriptureServiceProvider);
  return service.getVerses();
});

// One Veda by name (e.g. 'Rig Veda') — Sanskrit, premium-gated in the reader
final vedaVersesProvider = FutureProvider.family<List<Verse>, String>((ref, book) async {
  final service = ref.watch(scriptureServiceProvider);
  return service.getVedaVersesByBook(book);
});

// All Upanishad verses (across books) — Sanskrit, premium-gated in the reader.
final upanishadVersesProvider = FutureProvider<List<Verse>>((ref) async {
  final service = ref.watch(scriptureServiceProvider);
  return service.getUpanishadVerses();
});

// One random verse across ALL books for the Feed's Daily Reflection. Computed
// once per app launch, so it rotates on every page refresh.
final dailyReflectionProvider = FutureProvider<Verse?>((ref) async {
  final service = ref.watch(scriptureServiceProvider);
  return service.getRandomReflection();
});

// Resolves the user's bookmarks into full verses across ALL books
// (Gita, Vedas, Upanishads) — used by the Saved Wisdom tab.
final bookmarkedVersesProvider = FutureProvider<List<Verse>>((ref) async {
  final ids = ref.watch(bookmarksProvider);
  final service = ref.watch(scriptureServiceProvider);
  return service.getVersesByIds(ids);
});

// Bookmark IDs provider
class BookmarksNotifier extends StateNotifier<List<String>> {
  final ScriptureService _service;

  BookmarksNotifier(this._service) : super([]) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    state = await _service.getBookmarks();
  }

  Future<void> toggleBookmark(String id) async {
    final success = await _service.toggleBookmark(id);
    if (success) {
      state = [...state, id];
    } else {
      state = state.where((item) => item != id).toList();
    }
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<String>>((ref) {
  final service = ref.watch(scriptureServiceProvider);
  return BookmarksNotifier(service);
});

// Search query and results provider
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Verse>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final service = ref.watch(scriptureServiceProvider);
  return service.searchScriptures(query);
});

// Reader settings (Font size, Sanskrit script toggle, Transliteration toggle, Translation toggle)
class ReaderSettings {
  final double fontSizeMultiplier;
  final bool showSanskrit;
  final bool showTransliteration;
  final bool showTranslation;
  final bool showHindiTranslation;
  final bool showCommentary;

  const ReaderSettings({
    this.fontSizeMultiplier = 1.0,
    this.showSanskrit = true,
    this.showTransliteration = true,
    this.showTranslation = true,
    this.showHindiTranslation = false,
    this.showCommentary = true,
  });

  ReaderSettings copyWith({
    double? fontSizeMultiplier,
    bool? showSanskrit,
    bool? showTransliteration,
    bool? showTranslation,
    bool? showHindiTranslation,
    bool? showCommentary,
  }) {
    return ReaderSettings(
      fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
      showSanskrit: showSanskrit ?? this.showSanskrit,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      showTranslation: showTranslation ?? this.showTranslation,
      showHindiTranslation: showHindiTranslation ?? this.showHindiTranslation,
      showCommentary: showCommentary ?? this.showCommentary,
    );
  }
}

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(const ReaderSettings());

  void setFontSizeMultiplier(double val) {
    state = state.copyWith(fontSizeMultiplier: val);
  }

  void toggleSanskrit() {
    state = state.copyWith(showSanskrit: !state.showSanskrit);
  }

  void toggleTransliteration() {
    state = state.copyWith(showTransliteration: !state.showTransliteration);
  }

  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  void toggleHindiTranslation() {
    state = state.copyWith(showHindiTranslation: !state.showHindiTranslation);
  }

  void toggleCommentary() {
    state = state.copyWith(showCommentary: !state.showCommentary);
  }
}

final readerSettingsProvider = StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier();
});
