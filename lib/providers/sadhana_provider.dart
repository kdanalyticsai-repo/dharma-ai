import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/services/supabase_sync.dart';

class SadhanaState {
  final int streak;
  final int todayMeditation;
  final int targetMeditation;
  final int todayVerses;
  final int targetVerses;
  final int todayChanting;
  final int targetChanting;

  const SadhanaState({
    this.streak = 5, // Starts with a 5-day streak for motivation
    this.todayMeditation = 0,
    this.targetMeditation = 20,
    this.todayVerses = 0,
    this.targetVerses = 5,
    this.todayChanting = 0,
    this.targetChanting = 108,
  });

  double get overallProgress {
    final double medProg = (todayMeditation / targetMeditation).clamp(0.0, 1.0);
    final double verseProg = (todayVerses / targetVerses).clamp(0.0, 1.0);
    final double chantProg = (todayChanting / targetChanting).clamp(0.0, 1.0);
    return (medProg + verseProg + chantProg) / 3.0;
  }

  SadhanaState copyWith({
    int? streak,
    int? todayMeditation,
    int? targetMeditation,
    int? todayVerses,
    int? targetVerses,
    int? todayChanting,
    int? targetChanting,
  }) {
    return SadhanaState(
      streak: streak ?? this.streak,
      todayMeditation: todayMeditation ?? this.todayMeditation,
      targetMeditation: targetMeditation ?? this.targetMeditation,
      todayVerses: todayVerses ?? this.todayVerses,
      targetVerses: targetVerses ?? this.targetVerses,
      todayChanting: todayChanting ?? this.todayChanting,
      targetChanting: targetChanting ?? this.targetChanting,
    );
  }
}

class SadhanaNotifier extends StateNotifier<SadhanaState> {
  SadhanaNotifier() : super(const SadhanaState()) {
    _load();
  }

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      streak: prefs.getInt('sadhana_streak') ?? 5,
      todayMeditation: prefs.getInt('today_meditation') ?? 0,
      todayVerses: prefs.getInt('today_verses') ?? 0,
      todayChanting: prefs.getInt('today_chanting') ?? 0,
    );
    await _loadRemoteToday();
  }

  // Pull today's row from Supabase (source of truth when signed in).
  Future<void> _loadRemoteToday() async {
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) return;
    try {
      final row = await client.from('sadhana_records')
          .select()
          .eq('user_id', uid)
          .eq('date', _today)
          .maybeSingle();
      if (row != null) {
        state = state.copyWith(
          todayMeditation: row['meditation_minutes'] as int? ?? state.todayMeditation,
          todayVerses: row['verses_read'] as int? ?? state.todayVerses,
          todayChanting: row['chanting_rounds'] as int? ?? state.todayChanting,
          streak: row['streak_count'] as int? ?? state.streak,
        );
      }
    } catch (_) {
      // keep local state
    }
  }

  // Upsert today's record to Supabase (keyed on user_id + date).
  Future<void> _syncRemote() async {
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) return;
    try {
      await client.from('sadhana_records').upsert({
        'user_id': uid,
        'date': _today,
        'meditation_minutes': state.todayMeditation,
        'verses_read': state.todayVerses,
        'chanting_rounds': state.todayChanting,
        'streak_count': state.streak,
      }, onConflict: 'user_id,date');
    } catch (_) {
      // Non-blocking — local state already updated.
    }
  }

  Future<void> incrementMeditation(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = state.todayMeditation + minutes;
    await prefs.setInt('today_meditation', newVal);
    state = state.copyWith(todayMeditation: newVal);
    await _checkAndUpdateStreak();
    await _syncRemote();
  }

  Future<void> incrementVerses() async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = state.todayVerses + 1;
    await prefs.setInt('today_verses', newVal);
    state = state.copyWith(todayVerses: newVal);
    await _checkAndUpdateStreak();
    await _syncRemote();
  }

  Future<void> incrementChanting(int rounds) async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = state.todayChanting + rounds;
    await prefs.setInt('today_chanting', newVal);
    state = state.copyWith(todayChanting: newVal);
    await _checkAndUpdateStreak();
    await _syncRemote();
  }

  Future<void> resetToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('today_meditation', 0);
    await prefs.setInt('today_verses', 0);
    await prefs.setInt('today_chanting', 0);
    state = state.copyWith(
      todayMeditation: 0,
      todayVerses: 0,
      todayChanting: 0,
    );
    await _syncRemote();
  }

  Future<void> _checkAndUpdateStreak() async {
    // If user achieves all goals, increase streak
    if (state.todayMeditation >= state.targetMeditation &&
        state.todayVerses >= state.targetVerses &&
        state.todayChanting >= state.targetChanting) {
      final prefs = await SharedPreferences.getInstance();
      // Only increment streak if not already done today
      final streakUpdatedToday = prefs.getBool('streak_updated_today') ?? false;
      if (!streakUpdatedToday) {
        final newStreak = state.streak + 1;
        await prefs.setInt('sadhana_streak', newStreak);
        await prefs.setBool('streak_updated_today', true);
        state = state.copyWith(streak: newStreak);
      }
    }
  }
}

final sadhanaProvider = StateNotifierProvider<SadhanaNotifier, SadhanaState>((ref) {
  return SadhanaNotifier();
});
