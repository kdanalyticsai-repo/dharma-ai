import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/services/mock_scripture_data.dart';
import 'package:dharma_ai/screens/search_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/widgets/dharma_logo.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/sadhana_provider.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/providers/navigation_provider.dart';
import 'package:dharma_ai/providers/transliteration_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/profile_screen.dart';

class DailyFeedScreen extends ConsumerStatefulWidget {
  const DailyFeedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DailyFeedScreen> createState() => _DailyFeedScreenState();
}

class _DailyFeedScreenState extends ConsumerState<DailyFeedScreen> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sadhana = ref.watch(sadhanaProvider);
    final currentLanguage = ref.watch(languageProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final firstName = (fullName != null && fullName.isNotEmpty)
        ? fullName.split(' ').first
        : null;
    // Google sign-in provides a profile photo URL in auth metadata.
    final avatarUrl = (user?.userMetadata?['avatar_url'] ??
        user?.userMetadata?['picture']) as String?;
    // Show the name in the selected script (e.g. इन्द्र for Hindi); falls
    // back to the Latin name while loading / for English.
    final displayName = firstName == null
        ? null
        : (ref
                .watch(transliteratedNameProvider((name: firstName, lang: currentLanguage)))
                .valueOrNull ??
            firstName);

    // Daily Reflection: one random verse drawn from ALL books (Gita, Vedas,
    // Upanishads). Recomputed each app launch, so it rotates on every refresh.
    // While loading, show a bundled sample so the card never appears empty.
    final Verse dailyVerse = ref.watch(dailyReflectionProvider).valueOrNull ??
        MockScriptureData.gitaVerses.first;

    return Scaffold(
      body: MandalaBackground(
        scale: 0.85,
        alignment: Alignment.center,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Header (Greeting and Subtitle) — at the very top
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName != null
                              ? '${AppTranslations.get('greetingHariOm', currentLanguage)} $displayName'
                              : AppTranslations.get('greetingSeeker', currentLanguage),
                          style: textTheme.headlineMedium?.copyWith(
                            color: SacredTheme.headingColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppTranslations.get('greetingSubtitle', currentLanguage),
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        _subscriptionBadge(ref.watch(purchaseProvider)),
                        // Show validity for active plans, and a "defaulted to
                        // Free" notice once a subscription has lapsed.
                        ref.watch(subscriptionEndProvider).maybeWhen(
                          data: (end) {
                            final line = subscriptionStatusLine(end);
                            if (line == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                line,
                                style: textTheme.labelSmall?.copyWith(
                                  color: isSubscriptionExpired(end)
                                      ? SacredTheme.primary
                                      : SacredTheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: SacredTheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? Image.network(
                                  avatarUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _avatarInitial(firstName),
                                )
                              : _avatarInitial(firstName),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Center(child: DharmaLogo(height: 104)),

                const FadingDivider(height: 24),

                // Verse of the Day (Indigo Focus Card)
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SingleVerseDetailScreen(verse: dailyVerse),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(SacredTheme.radiusLg),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: SacredTheme.deepMeditativeIndigo,
                      borderRadius: BorderRadius.circular(SacredTheme.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: SacredTheme.deepMeditativeIndigo.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppTranslations.get('shlokaLabel', currentLanguage),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SacredTheme.templeGold,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const Icon(
                              Icons.menu_book,
                              color: SacredTheme.templeGold,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _formatSanskrit(dailyVerse.sanskritText),
                          style: GoogleFonts.notoSansDevanagari(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.95),
                            height: 1.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 16),
                        Text(
                          dailyVerse.getLocalizedTranslation(currentLanguage),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.45,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '${dailyVerse.bookName == 'Bhagavad Gita' ? AppTranslations.get('bhagavadGita', currentLanguage) : dailyVerse.bookName} ${dailyVerse.chapter}.${dailyVerse.verseNumber} ➔',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SacredTheme.templeGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: SacredTheme.stackLg),

                // Daily Sadhana — read-only snapshot. Logging happens on
                // the Sadhana tab so there's a single source of truth.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppTranslations.get('dailySadhanaCheckIn', currentLanguage),
                      style: textTheme.labelSmall?.copyWith(color: SacredTheme.primary),
                    ),
                    InkWell(
                      onTap: () => ref.read(homeTabProvider.notifier).state = 1,
                      borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              'Go to Sadhana',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SacredTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward, size: 13, color: SacredTheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SacredTheme.stackMd),

                _buildProgressRow(
                  context,
                  icon: Icons.self_improvement,
                  title: AppTranslations.get('meditateBreathe', currentLanguage),
                  current: sadhana.todayMeditation,
                  target: sadhana.targetMeditation,
                  unit: AppTranslations.get('minsLabel', currentLanguage),
                ),
                const SizedBox(height: SacredTheme.stackSm),
                _buildProgressRow(
                  context,
                  icon: Icons.auto_stories_outlined,
                  title: AppTranslations.get('readScripture', currentLanguage),
                  current: sadhana.todayVerses,
                  target: sadhana.targetVerses,
                  unit: AppTranslations.get('versesLabel', currentLanguage),
                ),
                const SizedBox(height: SacredTheme.stackSm),
                _buildProgressRow(
                  context,
                  icon: Icons.grain,
                  title: AppTranslations.get('aumJapaChanting', currentLanguage),
                  current: sadhana.todayChanting,
                  target: sadhana.targetChanting,
                  unit: AppTranslations.get('beadsLabel', currentLanguage),
                ),

                const SizedBox(height: SacredTheme.safeAreaBottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Gradient circle with the user's first initial (avatar fallback).
  Widget _avatarInitial(String? firstName) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SacredTheme.primary, SacredTheme.deepSaffron],
        ),
      ),
      child: Center(
        child: Text(
          firstName?.isNotEmpty == true ? firstName![0].toUpperCase() : 'S',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Read-only progress row: icon, title, a thin progress bar, and "x / y unit".
  Widget _buildProgressRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int current,
    required int target,
    required String unit,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final double progress = target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
    return Card(
      color: SacredTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SacredTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
              ),
              child: Icon(icon, color: SacredTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: SacredTheme.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation(SacredTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$current / $target $unit', style: textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  // Lay out a Sanskrit verse for comfortable reading: each pāda on its own
  // line (break after the daṇḍa "।" / double-daṇḍa "॥"), trimmed of blanks.
  String _formatSanskrit(String s) {
    return s
        .replaceAll(RegExp(r'\s*[\r\n]+\s*'), '\n') // normalise existing breaks
        .replaceAllMapped(RegExp(r'[।॥]'), (m) => '${m.group(0)}\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  // Subscription tier pill shown under the greeting (matches the profile badge).
  Widget _subscriptionBadge(SubscriptionTier tier) {
    final isAnnual = tier == SubscriptionTier.annual;
    final isSadhaka = tier == SubscriptionTier.sadhaka;
    final label = isAnnual
        ? '✦ Annual Sadhaka'
        : isSadhaka
            ? '★ Sadhaka Premium'
            : 'Free Seeker';
    final accent = isAnnual
        ? SacredTheme.deepGold
        : isSadhaka
            ? SacredTheme.primary
            : SacredTheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAnnual
            ? SacredTheme.deepGold.withOpacity(0.12)
            : isSadhaka
                ? SacredTheme.primary.withOpacity(0.1)
                : SacredTheme.outlineVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
        border: Border.all(color: accent.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: accent),
      ),
    );
  }
}
