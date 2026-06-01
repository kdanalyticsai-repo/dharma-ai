import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/chat_provider.dart' show aiServiceProvider;

typedef NameInLang = ({String name, AppLanguage lang});

/// Returns a personal name written in the selected language's script
/// (e.g. "Indra" → "इन्द्र" in Hindi). Result is cached in SharedPreferences
/// so it resolves instantly after the first lookup. Falls back to the
/// original Latin name for English, while loading, or on any error.
final transliteratedNameProvider =
    FutureProvider.family<String, NameInLang>((ref, arg) async {
  final name = arg.name.trim();
  if (name.isEmpty || arg.lang == AppLanguage.english) return name;

  final prefs = await SharedPreferences.getInstance();
  final key = 'translit_${arg.lang.code}_${name.toLowerCase()}';
  final cached = prefs.getString(key);
  if (cached != null && cached.isNotEmpty) return cached;

  final result = await ref.read(aiServiceProvider).transliterateName(name, arg.lang);
  if (result.isNotEmpty && result != name) {
    await prefs.setString(key, result);
  }
  return result;
});
