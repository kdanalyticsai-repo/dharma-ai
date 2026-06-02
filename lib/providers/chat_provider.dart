import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/models/chat_message.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/services/ai_service.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/services/qa_cache_service.dart';

const int kFreePromptLimit = 6;    // Max prompts per day (free tier)
const int kPaidDailyCap = 101;     // Fair-use soft cap for paid "unlimited" tiers
const int kRateLimitPerMinute = 3; // Max prompts per 60 seconds (all tiers)
// Annual tier keeps more context for the AI Guru (extended memory perk)
const int kAnnualHistoryDepth = 30;
const int kPaidHistoryDepth = 10;

// ── Shared daily prompt counter (across BOTH chat modes) ─────────────────────
// Both ScriptureChatNotifier and GuruChatNotifier read/write this provider
// so that the free daily prompts are consumed from a single shared pool.

class DailyPromptCounter extends StateNotifier<int> {
  DailyPromptCounter() : super(0) { _load(); }

  static const _countKey = _kSharedCountKey;
  static const _dateKey  = _kSharedDateKey;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today;
    final savedDate  = prefs.getString(_dateKey) ?? '';
    final savedCount = prefs.getInt(_countKey) ?? 0;
    state = savedDate == today ? savedCount : 0;
  }

  Future<void> increment() async {
    state = state + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, state);
    await prefs.setString(_dateKey, _today);
  }

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  bool get hasReachedLimit => state >= kFreePromptLimit;
  int  get remaining       => (kFreePromptLimit - state).clamp(0, kFreePromptLimit);

  // Fair-use soft cap so a single paid "unlimited" account can't run up
  // unbounded AI cost (abuse protection at scale).
  bool get hasReachedFairUse => state >= kPaidDailyCap;
}

final dailyPromptCounterProvider =
    StateNotifierProvider<DailyPromptCounter, int>((ref) => DailyPromptCounter());

// Provider for AI service
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

// Shared Scripture Scholar answer cache (cuts repeat OpenAI calls)
final qaCacheServiceProvider = Provider<QaCacheService>((ref) {
  return QaCacheService();
});

// Chat state structure
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final int dailyPromptCount;
  final String lastResetDate;           // "YYYY-MM-DD" — persisted
  final List<DateTime> recentTimestamps; // for per-minute rate limiting
  final bool isRateLimited;

  const ChatState({
    required this.messages,
    required this.isLoading,
    this.dailyPromptCount = 0,
    this.lastResetDate = '',
    this.recentTimestamps = const [],
    this.isRateLimited = false,
  });

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  int get todayCount => lastResetDate == _today ? dailyPromptCount : 0;

  bool get hasReachedFreeLimit => todayCount >= kFreePromptLimit;

  int get remainingFreePrompts =>
      (kFreePromptLimit - todayCount).clamp(0, kFreePromptLimit);

  // How many of the last-minute timestamps are within the 60s window
  int get requestsLastMinute {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    return recentTimestamps.where((t) => t.isAfter(cutoff)).length;
  }

  bool get hasHitRateLimit => requestsLastMinute >= kRateLimitPerMinute;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    int? dailyPromptCount,
    String? lastResetDate,
    List<DateTime>? recentTimestamps,
    bool? isRateLimited,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      dailyPromptCount: dailyPromptCount ?? this.dailyPromptCount,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      recentTimestamps: recentTimestamps ?? this.recentTimestamps,
      isRateLimited: isRateLimited ?? this.isRateLimited,
    );
  }
}

// State notifier for Scripture Chat (RAG-based)
// Shared keys — both chat modes draw from the same 11-prompt daily pool
const _kSharedCountKey = 'ai_daily_count';
const _kSharedDateKey  = 'ai_daily_date';

class ScriptureChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  static const _prefKeyCount = _kSharedCountKey;
  static const _prefKeyDate  = _kSharedDateKey;

  ScriptureChatNotifier(this._ref) : super(const ChatState(messages: [], isLoading: false)) {
    final currentLanguage = _ref.read(languageProvider);
    state = ChatState(
      messages: [
        ChatMessage(
          id: 'welcome_scripture',
          text: AppTranslations.get('welcomeScripture', currentLanguage),
          role: 'assistant',
          timestamp: DateTime.now(),
          isGuruMode: false,
        ),
      ],
      isLoading: false,
    );
    // Daily count loaded by shared dailyPromptCounterProvider
  }

  // Load the daily count from SharedPreferences on startup
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final tier    = _ref.read(purchaseProvider);
    final counter = _ref.read(dailyPromptCounterProvider.notifier);

    // Daily limit — Free users draw from the shared pool
    if (tier == SubscriptionTier.free && counter.hasReachedLimit) return;
    // Fair-use soft cap — protects paid "unlimited" tiers from abuse
    if (tier != SubscriptionTier.free && counter.hasReachedFairUse) {
      _notifyFairUse();
      return;
    }

    // Rate limit — all tiers
    if (state.hasHitRateLimit) {
      state = state.copyWith(isRateLimited: true);
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted) state = state.copyWith(isRateLimited: false);
      });
      return;
    }

    // Increment shared daily counter + update rate-limit timestamps
    await counter.increment();
    final updatedTimestamps = [
      ...state.recentTimestamps.where(
          (t) => t.isAfter(DateTime.now().subtract(const Duration(seconds: 60)))),
      DateTime.now(),
    ];
    state = state.copyWith(
      recentTimestamps: updatedTimestamps,
      isRateLimited: false,
    );

    final userMessage = ChatMessage(
      id: DateTime.now().toString(),
      text: text,
      role: 'user',
      timestamp: DateTime.now(),
      isGuruMode: false,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      final scriptureService = _ref.read(scriptureServiceProvider);
      final aiService = _ref.read(aiServiceProvider);
      final cache = _ref.read(qaCacheServiceProvider);
      final currentLanguage = _ref.read(languageProvider);

      // Check the shared answer cache first (avoids a repeat OpenAI call).
      Map<String, dynamic>? result = await cache.get(text, currentLanguage);
      if (result == null) {
        // Cache miss — perform RAG search, call the AI, then cache the answer.
        final contextVerses = await scriptureService.searchScriptures(text);
        result = await aiService.generateScriptureResponse(text, contextVerses, currentLanguage);
        await cache.put(text, currentLanguage, result);
      }

      final assistantMessage = ChatMessage(
        id: DateTime.now().toString(),
        text: result['text'] as String,
        role: 'assistant',
        timestamp: DateTime.now(),
        verseCitations: result['citations'] != null
            ? List<String>.from(result['citations'] as Iterable)
            : null,
        isGuruMode: false,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (e) {
      final currentLanguage = _ref.read(languageProvider);
      final errorMessage = ChatMessage(
        id: DateTime.now().toString(),
        text: '${AppTranslations.get('errorScripture', currentLanguage)} (Details: $e)',
        role: 'assistant',
        timestamp: DateTime.now(),
        isGuruMode: false,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
      );
    }
  }

  void clearHistory() {
    state = ChatState(
      messages: [
        state.messages.first, // Keep the welcome message
      ],
      isLoading: false,
    );
  }

  void _notifyFairUse() {
    final lang = _ref.read(languageProvider);
    final text = AppTranslations.get('fairUseLimit', lang);
    if (state.messages.isNotEmpty && state.messages.last.text == text) return;
    state = state.copyWith(messages: [
      ...state.messages,
      ChatMessage(
        id: DateTime.now().toString(),
        text: text,
        role: 'assistant',
        timestamp: DateTime.now(),
        isGuruMode: false,
      ),
    ]);
  }
}

final scriptureChatProvider = StateNotifierProvider<ScriptureChatNotifier, ChatState>((ref) {
  return ScriptureChatNotifier(ref);
});

// State notifier for Guru Mode (Conversation Memory)
class GuruChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  static const _prefKeyCount = _kSharedCountKey; // same pool as Scripture Scholar
  static const _prefKeyDate  = _kSharedDateKey;

  GuruChatNotifier(this._ref) : super(const ChatState(messages: [], isLoading: false)) {
    final currentLanguage = _ref.read(languageProvider);
    state = ChatState(
      messages: [
        ChatMessage(
          id: 'welcome_guru',
          text: AppTranslations.get('welcomeGuru', currentLanguage),
          role: 'assistant',
          timestamp: DateTime.now(),
          isGuruMode: true,
        ),
      ],
      isLoading: false,
    );
    // Daily count loaded by shared dailyPromptCounterProvider
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final tier    = _ref.read(purchaseProvider);
    final counter = _ref.read(dailyPromptCounterProvider.notifier);

    // Daily limit — Free users draw from the shared pool
    if (tier == SubscriptionTier.free && counter.hasReachedLimit) return;
    // Fair-use soft cap — protects paid "unlimited" tiers from abuse
    if (tier != SubscriptionTier.free && counter.hasReachedFairUse) {
      _notifyFairUse();
      return;
    }

    // Rate limit — all tiers
    if (state.hasHitRateLimit) {
      state = state.copyWith(isRateLimited: true);
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted) state = state.copyWith(isRateLimited: false);
      });
      return;
    }

    // Increment shared daily counter + update rate-limit timestamps
    await counter.increment();
    final updatedTimestamps = [
      ...state.recentTimestamps.where(
          (t) => t.isAfter(DateTime.now().subtract(const Duration(seconds: 60)))),
      DateTime.now(),
    ];
    state = state.copyWith(
      recentTimestamps: updatedTimestamps,
      isRateLimited: false,
    );

    final userMessage = ChatMessage(
      id: DateTime.now().toString(),
      text: text,
      role: 'user',
      timestamp: DateTime.now(),
      isGuruMode: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      final aiService = _ref.read(aiServiceProvider);
      final currentLanguage = _ref.read(languageProvider);

      // Annual tier gets deeper memory context; Monthly Premium gets standard depth
      final historyDepth = tier == SubscriptionTier.annual ? kAnnualHistoryDepth : kPaidHistoryDepth;
      final contextMessages = tier == SubscriptionTier.free
          ? state.messages
          : state.messages.length > historyDepth
              ? state.messages.sublist(state.messages.length - historyDepth)
              : state.messages;

      // Request AI response with tier-appropriate history
      final responseText = await aiService.generateGuruResponse(text, contextMessages, currentLanguage);

      final assistantMessage = ChatMessage(
        id: DateTime.now().toString(),
        text: responseText,
        role: 'assistant',
        timestamp: DateTime.now(),
        isGuruMode: true,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (e) {
      final currentLanguage = _ref.read(languageProvider);
      final errorMessage = ChatMessage(
        id: DateTime.now().toString(),
        text: AppTranslations.get('errorGuru', currentLanguage),
        role: 'assistant',
        timestamp: DateTime.now(),
        isGuruMode: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
      );
    }
  }

  void clearHistory() {
    state = ChatState(
      messages: [
        state.messages.first, // Keep welcome message
      ],
      isLoading: false,
    );
  }

  void _notifyFairUse() {
    final lang = _ref.read(languageProvider);
    final text = AppTranslations.get('fairUseLimit', lang);
    if (state.messages.isNotEmpty && state.messages.last.text == text) return;
    state = state.copyWith(messages: [
      ...state.messages,
      ChatMessage(
        id: DateTime.now().toString(),
        text: text,
        role: 'assistant',
        timestamp: DateTime.now(),
        isGuruMode: true,
      ),
    ]);
  }
}

final guruChatProvider = StateNotifierProvider<GuruChatNotifier, ChatState>((ref) {
  return GuruChatNotifier(ref);
});
