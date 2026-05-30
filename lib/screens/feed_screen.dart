import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/services/mock_scripture_data.dart';
import 'package:dharma_ai/screens/search_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/screens/profile_screen.dart';

class DailyFeedScreen extends ConsumerStatefulWidget {
  const DailyFeedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DailyFeedScreen> createState() => _DailyFeedScreenState();
}

class _DailyFeedScreenState extends ConsumerState<DailyFeedScreen> {
  // Mock sadhana habits state for Screen 6
  bool _readScriptureChecked = false;
  int _chantingRounds = 0;
  bool _meditated = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final firstName = (fullName != null && fullName.isNotEmpty)
        ? fullName.split(' ').first
        : null;

    // Rotate daily verse based on day of year so it changes each day
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final verseIndex = dayOfYear % MockScriptureData.gitaVerses.length;
    final Verse dailyVerse = MockScriptureData.gitaVerses[verseIndex];

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
                const SizedBox(height: 16),
                
                // Header (Greeting and Subtitle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName != null
                              ? 'Hari Om, $firstName'
                              : AppTranslations.get('greetingSeeker', currentLanguage),
                          style: textTheme.headlineMedium?.copyWith(
                            color: SacredTheme.meditativeIndigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppTranslations.get('greetingSubtitle', currentLanguage),
                          style: textTheme.bodyMedium,
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
                      borderRadius: BorderRadius.circular(20),
                      child: const CircleAvatar(
                        backgroundColor: SacredTheme.surfaceContainerHighest,
                        radius: 20,
                        child: Icon(Icons.person_outline, color: SacredTheme.primary),
                      ),
                    ),
                  ],
                ),
                
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
                          dailyVerse.sanskritText,
                          style: GoogleFonts.newsreader(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.95),
                            height: 1.6,
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
                            '${AppTranslations.get('bhagavadGita', currentLanguage)} ${dailyVerse.chapter}.${dailyVerse.verseNumber} ➔',
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

                // Sadhana Checklist (Check-ins)
                Text(
                  AppTranslations.get('dailySadhanaCheckIn', currentLanguage),
                  style: textTheme.labelSmall?.copyWith(color: SacredTheme.primary),
                ),
                const SizedBox(height: SacredTheme.stackMd),

                // Habit 1: Scripture Reading
                _buildSadhanaCard(
                  context,
                  title: AppTranslations.get('readScripture', currentLanguage),
                  subtitle: AppTranslations.get('readScriptureSub', currentLanguage),
                  icon: Icons.auto_stories_outlined,
                  trailing: Checkbox(
                    value: _readScriptureChecked,
                    activeColor: SacredTheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _readScriptureChecked = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(height: SacredTheme.stackSm),

                // Habit 2: Meditation
                _buildSadhanaCard(
                  context,
                  title: AppTranslations.get('meditateBreathe', currentLanguage),
                  subtitle: AppTranslations.get('meditateBreatheSub', currentLanguage),
                  icon: Icons.self_improvement,
                  trailing: InkWell(
                    onTap: () {
                      setState(() {
                        _meditated = !_meditated;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _meditated
                            ? SacredTheme.primary
                            : SacredTheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                      ),
                      child: Text(
                        _meditated
                            ? AppTranslations.get('completedBtn', currentLanguage)
                            : AppTranslations.get('beginBtn', currentLanguage),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _meditated ? Colors.white : SacredTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: SacredTheme.stackSm),

                // Habit 3: Chanting (Counter rounds)
                _buildSadhanaCard(
                  context,
                  title: AppTranslations.get('aumJapaChanting', currentLanguage),
                  subtitle: '${AppTranslations.get('currentlyLabel', currentLanguage)}: $_chantingRounds ${AppTranslations.get('roundsLabel', currentLanguage)}',
                  icon: Icons.grain,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: SacredTheme.outline),
                        onPressed: _chantingRounds > 0
                            ? () => setState(() => _chantingRounds--)
                            : null,
                      ),
                      Text('$_chantingRounds', style: textTheme.labelLarge),
                      IconButton(
                        icon: const Icon(Icons.add, color: SacredTheme.primary),
                        onPressed: () => setState(() => _chantingRounds++),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SacredTheme.safeAreaBottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSadhanaCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
  }) {
    final textTheme = Theme.of(context).textTheme;
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
                  Text(
                    subtitle,
                    style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
