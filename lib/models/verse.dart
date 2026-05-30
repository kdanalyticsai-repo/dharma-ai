import 'package:dharma_ai/providers/language_provider.dart';

class Verse {
  final String id;
  final String bookName;
  final int chapter;
  final int verseNumber;
  final String sanskritText;
  final String englishTransliteration;
  final String translation;
  final String commentary;
  final Map<String, String>? wordMeanings; // Sanskrit word -> translation

  const Verse({
    required this.id,
    required this.bookName,
    required this.chapter,
    required this.verseNumber,
    required this.sanskritText,
    required this.englishTransliteration,
    required this.translation,
    required this.commentary,
    this.wordMeanings,
  });

  String getLocalizedTranslation(AppLanguage lang) {
    return LocalizedScripture.translations[id]?[lang] ?? translation;
  }

  String getLocalizedCommentary(AppLanguage lang) {
    return LocalizedScripture.commentaries[id]?[lang] ?? commentary;
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookName': bookName,
      'chapter': chapter,
      'verseNumber': verseNumber,
      'sanskritText': sanskritText,
      'englishTransliteration': englishTransliteration,
      'translation': translation,
      'commentary': commentary,
      'wordMeanings': wordMeanings,
    };
  }

  // Create from JSON
  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      id: json['id'] as String,
      bookName: json['bookName'] as String? ?? 'Bhagavad Gita',
      chapter: json['chapter'] as int,
      verseNumber: json['verseNumber'] as int,
      sanskritText: json['sanskritText'] as String? ?? '',
      englishTransliteration: json['englishTransliteration'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      commentary: json['commentary'] as String? ?? '',
      wordMeanings: json['wordMeanings'] != null
          ? Map<String, String>.from(json['wordMeanings'] as Map)
          : null,
    );
  }
}
