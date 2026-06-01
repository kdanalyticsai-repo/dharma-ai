import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/screens/feed_screen.dart';
import 'package:dharma_ai/screens/reader_screen.dart';
import 'package:dharma_ai/screens/chat_parent_screen.dart';
import 'package:dharma_ai/screens/sadhana_screen.dart';
import 'package:dharma_ai/screens/sangha_screen.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/navigation_provider.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({Key? key}) : super(key: key);

  static const List<Widget> _screens = [
    DailyFeedScreen(),
    SadhanaScreen(),
    ChatParentScreen(),
    ScripturesScreen(),
    SanghaScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final currentIndex = ref.watch(homeTabProvider);

    return Scaffold(
      body: _screens[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: SacredTheme.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: SacredTheme.primary.withOpacity(0.1),
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return SacredTheme.lightTheme.textTheme.labelSmall?.copyWith(
                  color: SacredTheme.primary,
                  fontWeight: FontWeight.w600,
                );
              }
              return SacredTheme.lightTheme.textTheme.labelSmall?.copyWith(
                color: SacredTheme.onSurfaceVariant,
              );
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const IconThemeData(color: SacredTheme.primary, size: 24);
              }
              return const IconThemeData(color: SacredTheme.onSurfaceVariant, size: 22);
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              ref.read(homeTabProvider.notifier).state = index;
            },
            backgroundColor: SacredTheme.surfaceContainerLow,
            elevation: 0,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.wb_sunny_outlined),
                selectedIcon: const Icon(Icons.wb_sunny),
                label: AppTranslations.get('tabFeed', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(Icons.self_improvement_outlined),
                selectedIcon: const Icon(Icons.self_improvement),
                label: AppTranslations.get('tabSadhana', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(Icons.psychology_outlined),
                selectedIcon: const Icon(Icons.psychology),
                label: AppTranslations.get('tabAiGuru', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: AppTranslations.get('tabWisdom', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: AppTranslations.get('tabSangha', currentLanguage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Placeholder Mocks for Core Tabs (Phase 1)
// ==========================================

class MockFeedScreen extends StatelessWidget {
  const MockFeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Daily Feed', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: const MandalaBackground(
        scale: 0.8,
        alignment: Alignment.center,
        child: Center(
          child: Text('Screen 6: Daily Spiritual Feed Placeholder'),
        ),
      ),
    );
  }
}

class MockScripturesScreen extends StatelessWidget {
  const MockScripturesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Scriptures', style: textTheme.headlineMedium),
      ),
      body: const Center(
        child: Text('Screen 25 & 32: Scripture Reader & Search Placeholder'),
      ),
    );
  }
}

class MockAiGuruScreen extends StatelessWidget {
  const MockAiGuruScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('AI Guru', style: textTheme.headlineMedium),
      ),
      body: const Center(
        child: Text('Screen 19 & 21: AI Guidance & Guru Mode Placeholder'),
      ),
    );
  }
}

class MockSadhanaScreen extends StatelessWidget {
  const MockSadhanaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Sadhana', style: textTheme.headlineMedium),
      ),
      body: const Center(
        child: Text('Screen 37: Daily Sadhana Dashboard Placeholder'),
      ),
    );
  }
}

class MockSanghaScreen extends StatelessWidget {
  const MockSanghaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Sangha Community', style: textTheme.headlineMedium),
      ),
      body: const Center(
        child: Text('Screen 35: Sangha Community Feed Placeholder'),
      ),
    );
  }
}
