import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:dharma_ai/firebase_options.dart';
import 'package:dharma_ai/services/analytics_service.dart';
import 'package:dharma_ai/services/notification_service.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/screens/login_screen.dart';
import 'package:dharma_ai/screens/personalize_screen.dart';
import 'package:dharma_ai/services/google_intent_storage_stub.dart'
    if (dart.library.html) 'package:dharma_ai/services/google_intent_storage_web.dart';
import 'package:dharma_ai/screens/welcome_screen.dart';
import 'package:dharma_ai/screens/home_shell.dart';
import 'package:dharma_ai/screens/set_new_password_screen.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/providers/sadhana_provider.dart';
import 'package:dharma_ai/providers/chat_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/widgets/dharma_logo.dart';
import 'package:dharma_ai/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFAF7F2), // app's cream bg — keeps icons visible
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  // Firebase Analytics (web now; Android added later to the same project).
  // Guarded so a config/init issue can never block app startup.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    Analytics.attach();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  // Detect a password-recovery link from the URL. The reset email links to
  //   https://dharma.kdaanalytics.com/?type=recovery&token=<otp>&email=<email>
  // Web: read from Uri.base before Supabase.initialize() strips auth params.
  // Android: read from the App Link that launched the app (getInitialLink).
  Map<String, String> recoveryParams = const {};
  if (kIsWeb) {
    recoveryParams = Uri.base.queryParameters;
    // Read the Google OAuth intent from sessionStorage (written by auth_provider
    // before the OAuth redirect). sessionStorage survives same-tab redirects and
    // is more reliable than URL query params (which Supabase may strip).
    final intent = consumeGoogleIntent();
    if (intent != null) googleWebSignInIntent = intent;
  } else {
    try {
      final initialLink = await AppLinks().getInitialLink();
      if (initialLink != null) recoveryParams = initialLink.queryParameters;
    } catch (e) {
      debugPrint('AppLinks.getInitialLink failed: $e');
    }
  }
  final isRecovery = recoveryParams['type'] == 'recovery';
  final recoveryToken = recoveryParams['token'];
  final recoveryEmail = recoveryParams['email'];
  final recoveryTokenHash = recoveryParams['token_hash'];
  if (isRecovery) isRecoveringPassword = true;

  if (SupabaseConfig.isConfigured) {
    bool supabaseReady = false;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      supabaseReady = true;
    } catch (e) {
      debugPrint('Supabase.initialize failed: $e');
    }

    if (supabaseReady) {
      // Establish the recovery session from the emailed OTP (cross-browser).
      if (isRecovery) {
        try {
          if (recoveryToken != null && recoveryToken.isNotEmpty &&
              recoveryEmail != null && recoveryEmail.isNotEmpty) {
            await Supabase.instance.client.auth.verifyOTP(
              type: OtpType.recovery,
              email: recoveryEmail,
              token: recoveryToken,
            );
          } else if (recoveryTokenHash != null && recoveryTokenHash.isNotEmpty) {
            await Supabase.instance.client.auth.verifyOTP(
              type: OtpType.recovery,
              tokenHash: recoveryTokenHash,
            );
          }
        } catch (e) {
          debugPrint('recovery verifyOTP failed: $e');
        }
      }

      // Belt-and-suspenders: if the SDK does emit a passwordRecovery event, make
      // the set-password screen the only route so nothing bounces to Home.
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          // Enter recovery mode and make the set-password screen the only route,
          // so the auth listener below can't bounce the user to Home first.
          isRecoveringPassword = true;
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SetNewPasswordScreen()),
            (_) => false,
          );
        }
      });

      // Push notifications: Android + web browsers (non-blocking, never delays startup).
      NotificationService.initialize().catchError((e) {
        debugPrint('NotificationService init failed: $e');
      });

      // Android: handle auth links that arrive while the app is already running.
      if (!kIsWeb) {
        AppLinks().uriLinkStream.listen((uri) async {
          final params = uri.queryParameters;
          if (params['type'] == 'recovery') {
            final token = params['token'];
            final email = params['email'];
            final tokenHash = params['token_hash'];
            try {
              if (token != null && token.isNotEmpty &&
                  email != null && email.isNotEmpty) {
                await Supabase.instance.client.auth.verifyOTP(
                  type: OtpType.recovery,
                  email: email,
                  token: token,
                );
              } else if (tokenHash != null && tokenHash.isNotEmpty) {
                await Supabase.instance.client.auth.verifyOTP(
                  type: OtpType.recovery,
                  tokenHash: tokenHash,
                );
              }
            } catch (e) {
              debugPrint('deep link recovery verifyOTP failed: $e');
            }
          }
        });
      }
    }
  }

  // Production error/crash monitoring. The DSN is injected at build time
  // (--dart-define=SENTRY_DSN). When absent (local dev), Sentry is skipped and
  // the app runs exactly as before.
  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  if (sentryDsn.isEmpty) {
    runApp(ProviderScope(child: DharmaApp(navigatorKey: _navigatorKey)));
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = 'production';
        // Sample a fraction of transactions for performance tracing.
        options.tracesSampleRate = 0.2;
        // Drop a known-benign just_audio web error: AudioPlayer.dispose() rejects
        // with "UnimplementedError: dispose() has not been implemented." during
        // teardown on web. It doesn't affect the user; ignore it so it doesn't
        // create noise/regression alerts.
        options.beforeSend = (event, hint) {
          final detail = event.throwable?.toString() ??
              event.message?.formatted ??
              '';
          if (detail.contains('dispose() has not been implemented')) return null;
          // CanvasKit fails to get a WebGL/GPU context inside iOS in-app
          // browsers (FB/Insta webviews) and some locked-down iOS Safari
          // configs — "getParameter is not a function" from MakeWebGLContext.
          // It's environmental, not our bug, and CanvasKit falls back to CPU
          // rendering, so the app still loads. Drop the (escalating) noise.
          if (detail.contains('getParameter is not a function') ||
              detail.contains('MakeWebGLContext') ||
              detail.contains('MakeGrContext')) {
            return null;
          }
          return event;
        };
      },
      appRunner: () =>
          runApp(ProviderScope(child: DharmaApp(navigatorKey: _navigatorKey))),
    );
  }
}

final _navigatorKey = GlobalKey<NavigatorState>();

class DharmaApp extends ConsumerWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const DharmaApp({Key? key, required this.navigatorKey}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authUserProvider);

    // Imperatively navigate whenever the signed-in user changes.
    // MaterialApp.home changes alone don't navigate an already-mounted
    // Navigator — the NavigatorKey + pushAndRemoveUntil is the reliable fix.
    ref.listen(authUserProvider, (prev, next) {
      // During password recovery keep the user on the set-password screen.
      if (isRecoveringPassword) return;
      // During new-user onboarding LoginScreen/Google flow handles navigation
      // explicitly; skip here to avoid a double-navigation race condition.
      if (isNewUserOnboarding) return;

      final prevId = prev?.valueOrNull?.id;
      final nextId = next.valueOrNull?.id;
      if (prevId == nextId) return;

      // Defer navigation to the NEXT frame. Calling pushAndRemoveUntil
      // synchronously here (during a Riverpod provider-notification cycle)
      // triggers '_dependents.isEmpty' / 'ancestor not in tree' Flutter
      // assertions: the old route's widgets are still live in the element
      // tree when we start tearing them down.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = navigatorKey.currentState;
        if (nav == null) return;

        if (nextId != null) {
          if (kIsWeb) {
            // On web, the OAuth redirect reloads the page and wipes all widget
            // state. Apply the same 4-case (isNewUser × intent) routing as
            // Android, using the ?googleIntent= param captured at startup.
            final intent = googleWebSignInIntent;
            googleWebSignInIntent = null; // consume once
            final user = next.valueOrNull;
            final createdAt = DateTime.tryParse(user?.createdAt ?? '');
            final isNew = createdAt != null &&
                DateTime.now().toUtc().difference(createdAt).abs().inSeconds < 60;

            if (intent == 'signup' && isNew) {
              // New account from sign-up form → profile + onboarding.
              ref.read(authProvider.notifier).createGoogleProfile();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PersonalizeScreen()),
                (_) => false,
              );
            } else if (intent == 'signin' && isNew) {
              // Unregistered / deleted account on sign-in form → block.
              // LoginScreen will sign out the session and show the error.
              pendingGoogleAuthError = 'authGoogleNotRegistered';
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            } else if (intent == 'signup' && !isNew) {
              // Existing account on sign-up form → block.
              pendingGoogleAuthError = 'authGoogleAlreadyRegistered';
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen(startInSignUpMode: true)),
                (_) => false,
              );
            } else if (intent == 'signin' && !isNew) {
              // Existing account on sign-in form → home.
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeShell()),
                (_) => false,
              );
            } else {
              // No intent (page refresh with live session, or intent URL param
              // was stripped by the browser). Route by newness as fallback.
              if (isNew) {
                ref.read(authProvider.notifier).createGoogleProfile();
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PersonalizeScreen()),
                  (_) => false,
                );
              } else {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeShell()),
                  (_) => false,
                );
              }
            }
          } else {
            nav.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeShell()),
              (_) => false,
            );
          }
        } else if (prev?.hasValue == true) {
          // Only redirect to welcome when we had a session (not on initial load)
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (_) => false,
          );
        }

        // Invalidate per-user providers only after the navigation frame so the
        // old route's widgets (e.g. LoginScreen watching languageProvider) are
        // fully deactivated before providers are rebuilt.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.invalidate(purchaseProvider);
          ref.invalidate(activePlanProvider);
          ref.invalidate(subscriptionEndProvider);
          ref.invalidate(bookmarksProvider);
          ref.invalidate(sadhanaProvider);
          ref.invalidate(guruChatProvider);
          ref.invalidate(dailyPromptCounterProvider);
          ref.invalidate(languageProvider);
        });
      });
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DharmaAI',
      theme: SacredTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      // Auto-logs screen_view on route changes (no-op if analytics is off).
      navigatorObservers: [
        if (Analytics.observer != null) Analytics.observer!,
      ],
      // During password recovery, always show the set-password screen — the
      // user has a live session but must not be routed into the app first.
      home: isRecoveringPassword
          ? const SetNewPasswordScreen()
          : authState.when(
              data: (user) => user != null ? const HomeShell() : const WelcomeScreen(),
              loading: () => const _SplashScreen(),
              error: (_, __) => const WelcomeScreen(),
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAF7F2),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DharmaLogo(height: 104),
            SizedBox(height: 28),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
