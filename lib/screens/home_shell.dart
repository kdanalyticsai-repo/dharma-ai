import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/screens/feed_screen.dart';
import 'package:dharma_ai/screens/reader_screen.dart';
import 'package:dharma_ai/screens/chat_parent_screen.dart';
import 'package:dharma_ai/screens/sadhana_screen.dart';
import 'package:dharma_ai/screens/sangha_screen.dart';
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/navigation_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/supabase_sync.dart';
import 'package:dharma_ai/services/notification_service.dart';
import 'package:dharma_ai/widgets/app_download_banner.dart';
import 'package:dharma_ai/screens/onboarding_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const List<Widget> _screens = [
    DailyFeedScreen(),
    SadhanaScreen(),
    ChatParentScreen(),
    ScripturesScreen(),
    SanghaScreen(),
  ];

  StreamSubscription<String>? _notifTapSub;

  static const _sadhanaTabIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await maybeShowOnboarding(context);
      if (mounted) _maybeShowExpiryNotice();

      // App was terminated → user tapped notification to launch it (Android only;
      // always null on web since browsers have no terminated-app concept).
      final screen = NotificationService.pendingScreen;
      if (screen == 'sadhana' && mounted) {
        ref.read(homeTabProvider.notifier).state = _sadhanaTabIndex;
      }
    });

    // App was in background → user tapped notification (Android + web).
    _notifTapSub = NotificationService.onNotificationTap.listen((screen) {
      if (screen == 'sadhana' && mounted) {
        ref.read(homeTabProvider.notifier).state = _sadhanaTabIndex;
      }
    });
  }

  @override
  void dispose() {
    _notifTapSub?.cancel();
    super.dispose();
  }

  // Notify a user whose subscription has lapsed that they're now on Free.
  // Shown once per distinct expiry date per account (not on every refresh).
  Future<void> _maybeShowExpiryNotice() async {
    final DateTime? end = await ref.read(subscriptionEndProvider.future);
    if (!mounted || !isSubscriptionExpired(end)) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'expiry_notice_${SupabaseSync.userId ?? 'anon'}';
    final endIso = end!.toIso8601String();
    if (prefs.getString(key) == endIso) return; // already shown for this expiry
    await prefs.setString(key, endIso);
    if (!mounted) return;
    _showExpiryDialog(end);
  }

  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
    );
  }

  void _showExpiryDialog(DateTime end) {
    final lang = ref.read(languageProvider);
    final message =
        '${subscriptionStatusLine(end) ?? ''} '
        '${AppTranslations.get('expiryUpgradeBenefits', lang)}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SacredTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: SacredTheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(AppTranslations.get('expiryTitle', lang))),
          ],
        ),
        content: InkWell(
          onTap: () {
            Navigator.pop(ctx);
            _openPaywall();
          },
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTranslations.get('expiryMaybeLater', lang), style: const TextStyle(color: SacredTheme.outline)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openPaywall();
            },
            child: Text(AppTranslations.get('expiryUpgrade', lang)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = ref.watch(languageProvider);
    final currentIndex = ref.watch(homeTabProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFAF7F2),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
      body: _screens[currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppDownloadBanner(),
          Container(
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
                icon: const Icon(Icons.spa_outlined),
                selectedIcon: const Icon(Icons.spa),
                label: AppTranslations.get('tabSadhana', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: const Icon(Icons.auto_awesome),
                label: AppTranslations.get('tabAiGuru', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: AppTranslations.get('tabWisdom', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(Icons.group_outlined),
                selectedIcon: const Icon(Icons.group),
                label: AppTranslations.get('tabSangha', currentLanguage),
              ),
            ],
          ),       // NavigationBar
        ),         // NavigationBarTheme
      ),           // Container
      ],           // Column.children
    ),             // Column (bottomNavigationBar)
    ),             // Scaffold
    );             // AnnotatedRegion
  }
}
