import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dharma_ai/config/supabase_config.dart';
import 'package:dharma_ai/services/analytics_service.dart';
import 'package:dharma_ai/services/google_intent_storage_stub.dart'
    if (dart.library.html) 'package:dharma_ai/services/google_intent_storage_web.dart';

// Web Client ID from Firebase project (google-services.json → client_type: 3).
// Not a secret — it is embedded in the app and visible in web builds.
const _googleWebClientId =
    '494796756772-kv3raikt2k991emqbjp1er4tbnit62qs.apps.googleusercontent.com';

// True while the user is in the password-recovery flow (followed a reset link).
bool isRecoveringPassword = false;

// True when a brand-new user (email sign-up or first-time Google sign-in) is
// mid-onboarding. Prevents the global auth listener in DharmaApp from racing
// with the explicit navigation to PersonalizeScreen.
bool isNewUserOnboarding = false;

// Web-only: 'signup' or 'signin' — read from the ?googleIntent= URL param that
// main() encodes into the OAuth redirectTo before the browser redirect. Consumed
// once by the auth listener to apply the correct 4-case routing.
String? googleWebSignInIntent;

// Web-only: translation key set by the auth listener when a Google OAuth attempt
// is blocked (not-registered / already-registered). LoginScreen reads this in
// initState, signs out the session, and displays the localised message.
String? pendingGoogleAuthError;

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
      String email, String password, String name, {String? langCode}) async {
    if (!SupabaseConfig.isConfigured) {
      return (error: 'Backend not configured — check Supabase URL in settings.', needsConfirmation: false);
    }
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        // preferred_language drives the language of the confirmation/reset
        // emails (the Supabase templates branch on {{ .Data.preferred_language }}).
        data: {
          'full_name': name,
          if (langCode != null) 'preferred_language': langCode,
        },
      );
      // Supabase silently returns a user with empty identities when the email
      // is already registered — it never throws an error (email enumeration
      // protection). Detect this and surface a clear message.
      if (res.user?.identities?.isEmpty == true) {
        return (error: 't:authEmailAlreadyRegistered', needsConfirmation: false);
      }
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
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
        // Supabase returns the same error for wrong password and non-existent user.
        // Call a SECURITY DEFINER RPC so RLS doesn't hide the result from anonymous callers.
        try {
          final exists = await _client.rpc(
            'check_email_exists',
            params: {'p_email': email.trim().toLowerCase()},
          ) as bool;
          if (!exists) {
            // Sentinel prefix 't:' tells the UI to look this up in AppTranslations.
            return 't:authErrorNoAccount';
          }
        } catch (_) {
          // RPC not deployed yet — fall through to the generic message below.
        }
        return 't:authErrorWrongPassword';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Sign in with Google ─────────────────────────────────────
  // Returns (error, isNewUser).
  // isNewUser = true when no profile row exists after auth (first-time sign-in
  // OR deleted-account sign-in). Caller should route to PersonalizeScreen.
  //
  // [webIsSignUp] is web-only: encodes the user's form intent into the OAuth
  // redirectTo URL (?googleIntent=signup|signin) so main.dart can apply the
  // same 4-case routing logic after the browser redirect reloads the page.
  Future<({String? error, bool isNewUser})> signInWithGoogle({bool webIsSignUp = false}) async {
    if (kIsWeb) {
      try {
        // Persist the form intent in sessionStorage BEFORE the browser redirect.
        // sessionStorage survives same-tab OAuth redirects, so main.dart can
        // read it on reload and apply the correct 4-case routing.
        // (URL query params in redirectTo are unreliable: Supabase may strip
        //  them during redirect URL validation.)
        storeGoogleIntent(webIsSignUp ? 'signup' : 'signin');
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'https://dharma.kdaanalytics.com',
        );
        return (error: null, isNewUser: false); // web uses redirect; routing in main.dart
      } on AuthException catch (e) {
        return (error: e.message, isNewUser: false);
      } catch (e) {
        return (error: e.toString(), isNewUser: false);
      }
    }

    // Android: native account picker → ID token → Supabase signInWithIdToken.
    try {
      final gsi = GoogleSignIn(serverClientId: _googleWebClientId);
      // Clear any cached account so the picker always shows — without this
      // Android silently re-uses the last signed-in Google account.
      try { await gsi.signOut(); } catch (_) {}
      final googleUser = await gsi.signIn();
      if (googleUser == null) return (error: 'cancelled', isNewUser: false);

      // No deleted-account gate here. delete_user now removes the row from
      // auth.users (cascades). Re-signing in with Google creates a fresh auth
      // record; the profile check below then sees no profile → isNewUser=true →
      // onboarding. That IS re-registration, which is allowed.
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) return (error: 'Google sign-in failed: no ID token', isNewUser: false);

      final authResponse = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final user = authResponse.user;
      if (user == null) return (error: 'Google sign-in failed: no session', isNewUser: false);

      // Detect new vs returning user via auth record creation timestamp.
      // We cannot use profile-existence: the handle_new_user DB trigger fires
      // AFTER INSERT on auth.users and immediately creates a profile row, so a
      // profile always exists — even for a brand-new account created one second ago.
      // createdAt ≈ now (within 30 s) reliably means this auth row was just created.
      final createdAt = DateTime.tryParse(user.createdAt);
      final isNewUser = createdAt != null &&
          DateTime.now().toUtc().difference(createdAt).abs().inSeconds < 30;

      if (!isNewUser) {
        Analytics.login('google');
      }

      return (error: null, isNewUser: isNewUser);
    } on AuthException catch (e) {
      return (error: e.message, isNewUser: false);
    } catch (e) {
      return (error: e.toString(), isNewUser: false);
    }
  }

  // ── Create profile for a new Google user ───────────────────
  // Called by login_screen after confirming the user is on the sign-up form.
  // Separated from signInWithGoogle() so the sign-in form can block new users
  // without accidentally writing a profile row.
  Future<void> createGoogleProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final name = (user.userMetadata?['full_name'] as String?)
        ?? (user.userMetadata?['name'] as String?)
        ?? user.email
        ?? '';
    await _upsertProfile(user.id, name, user.email ?? '');
    Analytics.signUp('google');
  }

  // ── Sign out ────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Session may already be invalid (e.g. auth.users deleted). Still clear local state.
    }
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
        redirectTo: kIsWeb
          ? '${Uri.base.origin}/?type=recovery'
          : 'https://dharma.kdaanalytics.com/?type=recovery',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
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
