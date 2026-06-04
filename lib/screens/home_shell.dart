import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowExpiryNotice());
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
                icon: const Icon(PhosphorIconsRegular.sun),
                selectedIcon: const Icon(PhosphorIconsFill.sun),
                label: AppTranslations.get('tabFeed', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(PhosphorIconsRegular.flowerLotus),
                selectedIcon: const Icon(PhosphorIconsFill.flowerLotus),
                label: AppTranslations.get('tabSadhana', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(PhosphorIconsRegular.sparkle),
                selectedIcon: const Icon(PhosphorIconsFill.sparkle),
                label: AppTranslations.get('tabAiGuru', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(PhosphorIconsRegular.bookOpen),
                selectedIcon: const Icon(PhosphorIconsFill.bookOpen),
                label: AppTranslations.get('tabWisdom', currentLanguage),
              ),
              NavigationDestination(
                icon: const Icon(PhosphorIconsRegular.usersThree),
                selectedIcon: const Icon(PhosphorIconsFill.usersThree),
                label: AppTranslations.get('tabSangha', currentLanguage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
