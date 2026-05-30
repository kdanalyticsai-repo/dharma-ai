import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/lotus_painter.dart';

import 'package:dharma_ai/screens/search_screen.dart';
import 'package:dharma_ai/screens/audio_wisdom_screen.dart';
import 'package:dharma_ai/providers/language_provider.dart';

class ScripturesScreen extends ConsumerWidget {
  const ScripturesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versesAsync = ref.watch(versesProvider);
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);

    return Scaffold(
      body: MandalaBackground(
        scale: 0.9,
        alignment: Alignment.center,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppTranslations.get('bhagavadGita', currentLanguage),
                      style: textTheme.headlineLarge?.copyWith(
                        color: SacredTheme.meditativeIndigo,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search, color: SacredTheme.onSurfaceVariant),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ScriptureSearchScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.music_note, color: SacredTheme.onSurfaceVariant),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AudioWisdomScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: SacredTheme.onSurfaceVariant),
                          onPressed: () => _showSettingsBottomSheet(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const FadingDivider(height: 12),

              // Main Scripture List
              Expanded(
                child: versesAsync.when(
                  data: (verses) {
                    if (verses.isEmpty) {
                      return Center(child: Text(AppTranslations.get('noScripturesLoaded', currentLanguage)));
                    }
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: SacredTheme.marginEdge,
                        vertical: 16,
                      ),
                      itemCount: verses.length,
                      itemBuilder: (context, index) {
                        final verse = verses[index];
                        return VerseCard(verse: verse);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: LotusLoadingIndicator(size: 60),
                  ),
                  error: (err, stack) => Center(
                    child: Text('${AppTranslations.get('errorLoadingScriptures', currentLanguage)}: $err'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SacredTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(SacredTheme.radiusLg),
          topRight: Radius.circular(SacredTheme.radiusLg),
        ),
      ),
      builder: (context) {
        return const ReaderSettingsSheet();
      },
    );
  }
}

class VerseCard extends ConsumerWidget {
  final Verse verse;

  const VerseCard({Key? key, required this.verse}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    final currentLanguage = ref.watch(languageProvider);
    final textTheme = Theme.of(context).textTheme;
    
    final isBookmarked = bookmarks.contains(verse.id);

    // Dynamic sizes based on multiplier settings
    final double textScale = settings.fontSizeMultiplier;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Card(
        color: SacredTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
          side: const BorderSide(color: SacredTheme.templeGold, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (Chapter & Verse Number + Bookmark Icon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppTranslations.get('chapterLabel', currentLanguage)} ${verse.chapter}, ${AppTranslations.get('verseLabel', currentLanguage)} ${verse.verseNumber}',
                    style: textTheme.labelSmall?.copyWith(
                      color: SacredTheme.primary,
                      fontSize: (textTheme.labelSmall?.fontSize ?? 12) * textScale,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? SacredTheme.templeGold : SacredTheme.outline,
                    ),
                    onPressed: () {
                      ref.read(bookmarksProvider.notifier).toggleBookmark(verse.id);
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sanskrit text in Devanagari
              if (settings.showSanskrit && verse.sanskritText.isNotEmpty) ...[
                Center(
                  child: Text(
                    verse.sanskritText,
                    style: textTheme.titleLarge?.copyWith(
                      fontFamily: 'Newsreader',
                      fontSize: (textTheme.titleLarge?.fontSize ?? 20) * 1.15 * textScale,
                      color: SacredTheme.deepMeditativeIndigo,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Transliteration in Latin script
              if (settings.showTransliteration && verse.englishTransliteration.isNotEmpty && currentLanguage == AppLanguage.english) ...[
                Center(
                  child: Text(
                    verse.englishTransliteration,
                    style: textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Newsreader',
                      fontStyle: FontStyle.italic,
                      fontSize: (textTheme.bodyMedium?.fontSize ?? 14) * 1.15 * textScale,
                      color: SacredTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Custom Fading Divider
              if (settings.showSanskrit || (settings.showTransliteration && currentLanguage == AppLanguage.english))
                const FadingDivider(height: 16, thickness: 0.5),

              // English Translation
              if (settings.showTranslation && verse.translation.isNotEmpty) ...[
                Text(
                  AppTranslations.get('labelTranslation', currentLanguage),
                  style: textTheme.labelSmall?.copyWith(
                    color: SacredTheme.outline,
                    fontSize: (textTheme.labelSmall?.fontSize ?? 12) * textScale,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  verse.getLocalizedTranslation(currentLanguage),
                  style: textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: (textTheme.bodyLarge?.fontSize ?? 16) * textScale,
                    color: SacredTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Commentary
              if (settings.showCommentary && verse.commentary.isNotEmpty) ...[
                Text(
                  AppTranslations.get('labelCommentary', currentLanguage),
                  style: textTheme.labelSmall?.copyWith(
                    color: SacredTheme.outline,
                    fontSize: (textTheme.labelSmall?.fontSize ?? 12) * textScale,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  verse.getLocalizedCommentary(currentLanguage),
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: (textTheme.bodyMedium?.fontSize ?? 14) * textScale,
                    color: SacredTheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final currentLanguage = ref.watch(languageProvider);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: SacredTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('readingOptions', currentLanguage),
              style: textTheme.headlineSmall?.copyWith(color: SacredTheme.meditativeIndigo),
            ),
            const SizedBox(height: 16),

            // ── Font Size ──────────────────────────────────────
            _buildSectionLabel(context, 'TEXT SIZE'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.text_decrease, size: 16, color: SacredTheme.outline),
                Expanded(
                  child: Slider(
                    value: settings.fontSizeMultiplier,
                    min: 0.8, max: 1.5, divisions: 7,
                    activeColor: SacredTheme.primary,
                    onChanged: notifier.setFontSizeMultiplier,
                  ),
                ),
                const Icon(Icons.text_increase, size: 20, color: SacredTheme.outline),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SacredTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                  ),
                  child: Text(
                    '${(settings.fontSizeMultiplier * 100).toInt()}%',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: SacredTheme.primary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // ── Script options ─────────────────────────────────
            _buildSectionLabel(context, 'SCRIPT'),
            const SizedBox(height: 8),
            _buildToggleItem(
              context,
              icon: Icons.auto_stories,
              label: AppTranslations.get('showSanskritDevanagari', currentLanguage),
              subtitle: 'देवनागरी',
              value: settings.showSanskrit,
              onChanged: (_) => notifier.toggleSanskrit(),
            ),
            if (currentLanguage == AppLanguage.english)
              _buildToggleItem(
                context,
                icon: Icons.sort_by_alpha,
                label: AppTranslations.get('showSanskritTransliteration', currentLanguage),
                subtitle: 'IAST romanization',
                value: settings.showTransliteration,
                onChanged: (_) => notifier.toggleTransliteration(),
              ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // ── Content options ────────────────────────────────
            _buildSectionLabel(context, 'CONTENT'),
            const SizedBox(height: 8),
            _buildToggleItem(
              context,
              icon: Icons.menu_book,
              label: AppTranslations.get('showTranslationToggle', currentLanguage),
              subtitle: 'English meaning of each verse',
              value: settings.showTranslation,
              onChanged: (_) => notifier.toggleTranslation(),
            ),
            _buildToggleItem(
              context,
              icon: Icons.lightbulb_outline,
              label: AppTranslations.get('showCommentaryToggle', currentLanguage),
              subtitle: 'Philosophical explanation',
              value: settings.showCommentary,
              onChanged: (_) => notifier.toggleCommentary(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: SacredTheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildToggleItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: SacredTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
            ),
            child: Icon(icon, color: SacredTheme.meditativeIndigo, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyMedium),
                if (subtitle != null)
                  Text(subtitle, style: textTheme.labelSmall?.copyWith(color: SacredTheme.outline)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: SacredTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
