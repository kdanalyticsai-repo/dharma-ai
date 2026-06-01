import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/config/supabase_config.dart';

// Current Supabase user.
// Yields the already-restored session synchronously (from localStorage,
// populated by Supabase.initialize()) so page refresh keeps the user
// signed in. Then follows all subsequent SIGNED_IN / SIGNED_OUT events.
final authUserProvider = StreamProvider<User?>((ref) async* {
  if (!SupabaseConfig.isConfigured) { yield null; return; }
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession?.user; // synchronous, available after initialize()
  yield* auth.onAuthStateChange.map((e) => e.session?.user);
});

// Convenience: is the user signed in?
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authUserProvider).valueOrNull != null;
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    if (!SupabaseConfig.isConfigured) {
      state = const AsyncValue.data(null);
      return;
    }
    final session = Supabase.instance.client.auth.currentSession;
    state = AsyncValue.data(session?.user);
  }

  SupabaseClient get _client => Supabase.instance.client;

  // ── Sign up with email + password ──────────────────────────
  Future<String?> signUp(String email, String password, String name) async {
    if (!SupabaseConfig.isConfigured) return 'Backend not configured — check Supabase URL in settings.';
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      state = AsyncValue.data(res.user);
      if (res.user != null) {
        try {
          await _upsertProfile(res.user!.id, name, email);
        } catch (_) {
          // Profile row creation failed but auth succeeded — not blocking
        }
      }
      return null; // null = success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Sign in with email + password ──────────────────────────
  Future<String?> signIn(String email, String password) async {
    if (!SupabaseConfig.isConfigured) return 'Backend not configured — check Supabase URL in settings.';
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(res.user);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Sign in with Google ─────────────────────────────────────
  Future<String?> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://dharma.kdaanalytics.com',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Sign out ────────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }

  // ── Reset password ──────────────────────────────────────────
  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  // ── Create/update user profile row in DB ────────────────────
  Future<void> _upsertProfile(String uid, String name, String email) async {
    await _client.from('profiles').upsert({
      'id': uid,
      'full_name': name,
      'email': email,
      'subscription_tier': 'free',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});
