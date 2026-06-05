import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/config/supabase_config.dart';
import 'package:dharma_ai/services/analytics_service.dart';

// True while the user is in the password-recovery flow (followed a reset link).
// The recovery link establishes a real session, so the global auth listener
// would otherwise bounce them to Home — this flag holds them on the
// "set a new password" screen until they finish. Cleared once the new password
// is saved (or the app is restarted).
bool isRecoveringPassword = false;

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
  // Returns (error, needsConfirmation):
  //  • error != null              → failed
  //  • needsConfirmation == true  → account created but email must be confirmed
  //    (Supabase "Confirm email" is on); NO session yet, so do NOT route to app.
  //  • both falsey                → signed in immediately (confirmation off).
  Future<({String? error, bool needsConfirmation})> signUp(
      String email, String password, String name) async {
    if (!SupabaseConfig.isConfigured) {
      return (error: 'Backend not configured — check Supabase URL in settings.', needsConfirmation: false);
    }
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      // With "Confirm email" on, signUp returns a user but NO session.
      final needsConfirmation = res.session == null;
      if (!needsConfirmation) {
        state = AsyncValue.data(res.user);
        if (res.user != null) {
          Analytics.signUp('email');
          try {
            await _upsertProfile(res.user!.id, name, email);
          } catch (_) {
            // Profile row creation failed but auth succeeded — not blocking
          }
        }
      }
      // (When confirmation is required the profile is created server-side by the
      // handle_new_user trigger; a client upsert would fail without a session.)
      return (error: null, needsConfirmation: needsConfirmation);
    } on AuthException catch (e) {
      return (error: e.message, needsConfirmation: false);
    } catch (e) {
      return (error: e.toString(), needsConfirmation: false);
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
      Analytics.login('email');
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
  // Sends a recovery link. On web we redirect back to the current origin
  // (auto-adapts to dev/prod) so the app can catch the passwordRecovery
  // event and let the user set a new password.
  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        // Tag the redirect so the app can recognise a recovery on load. Under
        // the PKCE flow Supabase does NOT reliably emit a passwordRecovery
        // event, so this marker is how we know to show the set-password screen
        // instead of dropping the user on the feed.
        redirectTo: kIsWeb ? '${Uri.base.origin}/?type=recovery' : null,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  // ── Set a new password (after clicking the recovery link) ───
  Future<String?> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
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
