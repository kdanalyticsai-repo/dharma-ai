import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/screens/welcome_screen.dart';
import 'package:dharma_ai/screens/home_shell.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: DharmaApp()));
}

class DharmaApp extends ConsumerWidget {
  const DharmaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authUserProvider);

    return MaterialApp(
      title: 'DharmaAI',
      theme: SacredTheme.lightTheme,
      darkTheme: SacredTheme.darkTheme,
      themeMode: ThemeMode.system,
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
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
