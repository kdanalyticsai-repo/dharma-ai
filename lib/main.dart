import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/screens/welcome_screen.dart';
import 'package:dharma_ai/screens/home_shell.dart';
import 'package:dharma_ai/screens/set_new_password_screen.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/providers/sadhana_provider.dart';
import 'package:dharma_ai/widgets/dharma_logo.dart';
import 'package:dharma_ai/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    // When the user follows a password-recovery email link, Supabase opens a
    // temporary recovery session and fires this event — send them to the
    // "set a new password" screen.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const SetNewPasswordScreen()),
        );
      }
    });
  }

  runApp(ProviderScope(child: DharmaApp(navigatorKey: _navigatorKey)));
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
      final prevId = prev?.valueOrNull?.id;
      final nextId = next.valueOrNull?.id;
      if (prevId == nextId) return;

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      if (nextId != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      } else if (prev?.hasValue == true) {
        // Only redirect to welcome when we had a session (not on initial load)
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      }

      // Reset per-user data providers
      ref.invalidate(purchaseProvider);
      ref.invalidate(bookmarksProvider);
      ref.invalidate(sadhanaProvider);
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DharmaAI',
      theme: SacredTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: authState.when(
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
