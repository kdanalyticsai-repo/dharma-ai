import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/models/chat_message.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/config/openai_config.dart';

class AiService {

  // ── System Prompts ────────────────────────────────────────────

  static const String _scriptureSystemPrompt =
      'You are a wise and scholarly AI scripture expert specialising in the '
      'Bhagavad Gita and Vedic philosophy. '
      'Answer the user\'s question by referencing the provided verse context. '
      'Cite specific verses (e.g. "Chapter 2, Verse 47") where relevant. '
      'Keep your tone serene, objective, and deeply respectful of ancient '
      'philosophical traditions. Explain Sanskrit terms when helpful. '
      'Be concise — aim for 3-5 sentences unless depth is needed.';

  static const String _guruSystemPrompt =
      'You are a serene, compassionate, and wise spiritual Guru in the Vedic '
      'tradition. Your purpose is to provide guidance, comfort, and '
      'philosophical counsel like a traditional teacher. '
      'Respond with deep empathy, using traditional analogies such as the '
      'lotus flower, the deep ocean, the lamp of knowledge, or the chariot '
      'of the mind. Refer to scriptural teachings naturally, not academically. '
      'Keep your tone warm, soothing, and introspective. '
      'You may close with a peaceful "Om Shanti". '
      'Be concise — 4-6 sentences unless the seeker needs more.';

  // ── 1. Scripture Chat (RAG) ───────────────────────────────────

  // Appends a personalisation line so the AI addresses the user by their first
  // name — but does NOT repeat the opening "Radhey Radhey" greeting in every
  // reply (the conversation already opens with it), to avoid monotony.
  static String _withName(String base, String? userName) {
    final first = (userName ?? '').trim().split(' ').first.trim();
    if (first.isEmpty) return base;
    return '$base\nThe person you are speaking with is named $first. Address '
        'them warmly by their first name when it feels natural, but do NOT '
        'begin your replies with "Radhey Radhey" or repeat any greeting — the '
        'conversation has already opened with that greeting.';
  }

  Future<Map<String, dynamic>> generateScriptureResponse(
    String prompt,
    List<Verse> contextVerses,
    AppLanguage language, {
    String? userName,
  }) async {
    if (OpenAIConfig.isConfigured) {
      try {
        return await _callOpenAIScripture(prompt, contextVerses, language, userName);
      } catch (e) {
        debugPrint('⚠️  OpenAI Scripture error: $e');
        return {'text': '⚠️ AI error: $e', 'citations': <String>[]};
      }
    }
    await Future.delayed(const Duration(milliseconds: 1500));
    return _simulateScriptureResponse(prompt, contextVerses, language);
  }

  // ── 2. Guru Mode (Conversational Memory) ─────────────────────

  Future<String> generateGuruResponse(
    String prompt,
    List<ChatMessage> history,
    AppLanguage language, {
    String? userName,
  }) async {
    if (OpenAIConfig.isConfigured) {
      try {
        return await _callOpenAIGuru(prompt, history, language, userName);
      } catch (e) {
        debugPrint('⚠️  OpenAI Guru error: $e');
        return '⚠️ AI error: $e';
      }
    }
    await Future.delayed(const Duration(milliseconds: 1800));
    return _simulateGuruResponse(prompt, history, language);
  }

  // ── Name transliteration (Latin → selected script) ──────────
  // Returns the name written in the language's native script. Returns the
  // original name for English, when not configured, or on any error.
  Future<String> transliterateName(String name, AppLanguage language) async {
    if (!OpenAIConfig.isConfigured) return name;
    final String script;
    switch (language) {
      case AppLanguage.hindi:
        script = 'Devanagari (Hindi)';
        break;
      case AppLanguage.tamil:
        script = 'Tamil';
        break;
      case AppLanguage.bengali:
        script = 'Bengali';
        break;
      default:
        return name; // English / unknown — keep as-is
    }
    try {
      final result = await _postToOpenAI([
        {
          'role': 'system',
          'content':
              'You transliterate personal names into other scripts, preserving '
              'pronunciation. Output ONLY the transliterated name — no quotes, '
              'punctuation, romanization, or any extra words.'
        },
        {'role': 'user', 'content': 'Transliterate this name into $script script: $name'},
      ]);
      final cleaned = result.trim().split('\n').first.trim();
      return cleaned.isEmpty ? name : cleaned;
    } catch (_) {
      return name;
    }
  }

  // ── OpenAI: Scripture Chat ────────────────────────────────────

  Future<Map<String, dynamic>> _callOpenAIScripture(
    String prompt,
    List<Verse> contextVerses,
    AppLanguage language,
    String? userName,
  ) async {
    final contextBlock = contextVerses.isNotEmpty
        ? contextVerses.map((v) =>
            '[${v.id}] ${v.bookName} Ch.${v.chapter} V.${v.verseNumber}\n'
            'Sanskrit: ${v.sanskritText}\n'
            'Translation: ${v.getLocalizedTranslation(language)}\n'
            'Commentary: ${v.getLocalizedCommentary(language)}')
            .join('\n\n')
        : 'No specific verse context — answer from general Vedic knowledge.';

    final languageNote = language == AppLanguage.english
        ? 'Respond in English.'
        : 'Respond in ${language.displayName} if possible, otherwise English.';

    final messages = [
      {'role': 'system', 'content': _withName(_scriptureSystemPrompt, userName)},
      {
        'role': 'user',
        'content': 'Verse context:\n$contextBlock\n\nQuestion: $prompt\n\n$languageNote'
      },
    ];

    final responseText = await _postToOpenAI(messages);

    final citations = contextVerses
        .where((v) =>
            responseText.contains(v.id) ||
            responseText.contains('${v.chapter}.${v.verseNumber}') ||
            responseText.contains('Chapter ${v.chapter}'))
        .map((v) => v.id)
        .toList();

    return {'text': responseText, 'citations': citations};
  }

  // ── OpenAI: Guru Mode ─────────────────────────────────────────

  Future<String> _callOpenAIGuru(
    String prompt,
    List<ChatMessage> history,
    AppLanguage language,
    String? userName,
  ) async {
    final languageNote = language == AppLanguage.english
        ? 'Respond in English.'
        : 'Respond in ${language.displayName} if possible, otherwise English.';

    // Build messages: system + history + current message
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _withName(_guruSystemPrompt, userName)},
    ];

    // Add conversation history (skip welcome message at index 0)
    for (final msg in history.skip(1)) {
      messages.add({
        'role': msg.role == 'user' ? 'user' : 'assistant',
        'content': msg.text,
      });
    }

    // Current message
    messages.add({
      'role': 'user',
      'content': '$prompt\n\n($languageNote)',
    });

    return await _postToOpenAI(messages);
  }

  // ── Shared HTTP call ──────────────────────────────────────────

  // The signed-in user's Supabase access token (null if not signed in /
  // Supabase not initialised). Safe to call anywhere.
  String? _supabaseToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<String> _postToOpenAI(List<Map<String, dynamic>> messages) async {
    final body = {
      'model': OpenAIConfig.model,
      'messages': messages,
      'temperature': 0.75,
      'max_tokens': 600,
    };

    final headers = Map<String, String>.from(OpenAIConfig.headers);
    // In production the request goes through the Worker, which requires the
    // caller's Supabase token to confirm a real signed-in user.
    if (OpenAIConfig.usesWorker) {
      final token = _supabaseToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .post(
          Uri.parse(OpenAIConfig.baseUrl),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Your session expired. Please sign in again.');
    }
    if (response.statusCode == 429) {
      throw Exception('Too many requests. Please wait a moment before asking again.');
    }
    if (response.statusCode != 200) {
      throw Exception('Service temporarily unavailable. Please try again shortly.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>;
    if (choices.isEmpty) throw Exception('OpenAI returned no choices');

    return choices[0]['message']['content'] as String;
  }

  // ── Local Simulation Fallback ─────────────────────────────────

  Map<String, dynamic> _simulateScriptureResponse(
      String prompt, List<Verse> context, AppLanguage language) {
    final q = prompt.toLowerCase();
    if (context.isNotEmpty) {
      if (q.contains('work') || q.contains('anxiety') || q.contains('2.47')) {
        return {
          'text': AppTranslations.get('aiScriptureWorkResponse', language),
          'citations': [context.first.id],
        };
      }
      if (q.contains('soul') || q.contains('death') || q.contains('2.20')) {
        return {
          'text': AppTranslations.get('aiScriptureSoulResponse', language),
          'citations': [context.first.id],
        };
      }
    }
    return {
      'text': AppTranslations.get('aiScriptureDefaultResponse', language),
      'citations': context.isNotEmpty ? [context.first.id] : <String>[],
    };
  }

  String _simulateGuruResponse(
      String prompt, List<ChatMessage> history, AppLanguage language) {
    final q = prompt.toLowerCase();
    if (q.contains('anxious') || q.contains('worry') || q.contains('scared')) {
      return AppTranslations.get('aiGuruAnxietyResponse', language);
    }
    if (q.contains('duty') || q.contains('karma') || q.contains('what should i do')) {
      return AppTranslations.get('aiGuruDutyResponse', language);
    }
    if (q.contains('sad') || q.contains('grief') || q.contains('lonely')) {
      return AppTranslations.get('aiGuruSadnessResponse', language);
    }
    return AppTranslations.get('aiGuruDefaultResponse', language);
  }
}
