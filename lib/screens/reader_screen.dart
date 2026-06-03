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
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/services/mock_scripture_data.dart';

// Scripture collections shown in the Wisdom reader.
// Gita is free; Upanishads and Vedas are Premium/Annual only.
enum ScriptureBook { gita, upanishads, vedas }

final selectedBookProvider =
    StateProvider<ScriptureBook>((ref) => ScriptureBook.gita);

// Which Veda is shown within the Vedas tab.
final selectedVedaProvider = StateProvider<String>((ref) => 'Rig Veda');

class ScripturesScreen extends ConsumerWidget {
  const ScripturesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versesAsync = ref.watch(versesProvider);
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);
    final selectedBook = ref.watch(selectedBookProvider);
    final tier = ref.watch(purchaseProvider);
    final isPaid = tier != SubscriptionTier.free;

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
                      selectedBook == ScriptureBook.gita
                          ? AppTranslations.get('bhagavadGita', currentLanguage)
                          : selectedBook == ScriptureBook.upanishads
                              ? 'Upanishads'
                              : 'Vedas',
                      style: textTheme.headlineLarge?.copyWith(
                        color: SacredTheme.headingColor(context),
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

              // Scripture collection selector (Gita / Upanishads / Vedas)
              _buildBookSelector(context, ref, selectedBook),

              const FadingDivider(height: 12),

              // Content — Gita is free; Upanishads/Vedas require a paid tier
              Expanded(
                child: _buildBookContent(
                  context, ref, selectedBook, isPaid, versesAsync, currentLanguage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookSelector(BuildContext context, WidgetRef ref, ScriptureBook selected) {
    Widget chip(String label, ScriptureBook book, {bool locked = false}) {
      final isSel = selected == book;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => ref.read(selectedBookProvider.notifier).state = book,
          borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? SacredTheme.primary : SacredTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
              border: Border.all(
                color: isSel ? SacredTheme.primary : SacredTheme.outlineVariant,
                width: isSel ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                    color: isSel ? Colors.white : SacredTheme.onSurface,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.lock, size: 12,
                      color: isSel ? Colors.white : SacredTheme.outline),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final isPaid = ref.watch(purchaseProvider) != SubscriptionTier.free;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
      child: Row(
        children: [
          chip('Bhagavad Gita', ScriptureBook.gita),
          chip('Upanishads', ScriptureBook.upanishads, locked: !isPaid),
          chip('Vedas', ScriptureBook.vedas, locked: !isPaid),
        ],
      ),
    );
  }

  Widget _buildBookContent(
    BuildContext context,
    WidgetRef ref,
    ScriptureBook book,
    bool isPaid,
    AsyncValue<List<Verse>> gitaAsync,
    AppLanguage lang,
  ) {
    // Gita — available to everyone
    if (book == ScriptureBook.gita) {
      return gitaAsync.when(
        data: (verses) {
          if (verses.isEmpty) {
            return Center(child: Text(AppTranslations.get('noScripturesLoaded', lang)));
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 16),
            itemCount: verses.length,
            itemBuilder: (context, index) => VerseCard(verse: verses[index]),
          );
        },
        loading: () => const Center(child: LotusLoadingIndicator(size: 60)),
        error: (err, stack) => Center(
          child: Text('${AppTranslations.get('errorLoadingScriptures', lang)}: $err'),
        ),
      );
    }

    // Upanishads / Vedas — Premium gate
    if (!isPaid) {
      return _buildPremiumGate(context, book);
    }

    // Vedas come from Supabase (full Sanskrit text); samples as fallback.
    if (book == ScriptureBook.vedas) {
      final selectedVeda = ref.watch(selectedVedaProvider);
      Widget shell(List<Verse> verses) {
        return Column(
          children: [
            _vedaSubFilter(context, ref, selectedVeda),
            _aiAssistedBanner(context),
            _samavedaNote(context),
            Expanded(
              child: verses.isEmpty
                  ? Center(child: Text('No verses found for $selectedVeda.',
                      style: Theme.of(context).textTheme.bodyMedium))
                  : _verseList(verses),
            ),
          ],
        );
      }

      return ref.watch(vedaVersesProvider(selectedVeda)).when(
        data: (verses) => shell(verses),
        loading: () => Column(
          children: [
            _vedaSubFilter(context, ref, selectedVeda),
            const Expanded(child: Center(child: LotusLoadingIndicator(size: 60))),
          ],
        ),
        error: (_, __) => shell(
            MockScriptureData.vedaVerses.where((v) => v.bookName == selectedVeda).toList()),
      );
    }

    // Upanishads — Sanskrit verse text (public domain) from Supabase;
    // transliteration, translation and commentary are AI-assisted. Curated
    // samples are the fallback if Supabase is empty/unavailable.
    Widget upaShell(List<Verse> verses) {
      return Column(
        children: [
          _upanishadNote(context),
          Expanded(
            child: verses.isEmpty
                ? Center(child: Text('No verses found.',
                    style: Theme.of(context).textTheme.bodyMedium))
                : _verseList(verses),
          ),
        ],
      );
    }

    return ref.watch(upanishadVersesProvider).when(
      data: (verses) => upaShell(verses),
      loading: () => const Center(child: LotusLoadingIndicator(size: 60)),
      error: (_, __) => upaShell(MockScriptureData.upanishadVerses),
    );
  }

  Widget _upanishadNote(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SacredTheme.templeGold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
        border: Border.all(color: SacredTheme.templeGold.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: SacredTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sanskrit verses are the public-domain original; transliteration, '
              'translation and commentary are AI-assisted — please verify against '
              'traditional scholarly sources.',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: SacredTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiAssistedBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SacredTheme.templeGold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
        border: Border.all(color: SacredTheme.templeGold.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: SacredTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Veda translations are AI-assisted — please verify against traditional scholarly sources.',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: SacredTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vedaSubFilter(BuildContext context, WidgetRef ref, String selected) {
    Widget chip(String book) {
      final sel = selected == book;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => ref.read(selectedVedaProvider.notifier).state = book,
          borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? SacredTheme.templeGold : SacredTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
              border: Border.all(
                color: sel ? SacredTheme.templeGold : SacredTheme.outlineVariant,
                width: sel ? 1.0 : 0.5,
              ),
            ),
            child: Text(
              book,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                color: sel ? Colors.white : SacredTheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
      child: Row(
        children: [chip('Rig Veda'), chip('Yajur Veda'), chip('Atharva Veda')],
      ),
    );
  }

  Widget _samavedaNote(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 8, SacredTheme.marginEdge, 0),
      child: Text(
        'Note: The library includes the Rig, Yajur and Atharva Veda. The '
        'Sama Veda is the melodic (sāman) arrangement of Rig Veda hymns for '
        'chanting — its verses are largely drawn from the Rig Veda already here.\n\n'
        'Sanskrit source: DharmicData (Open Database License). Translations are '
        'AI-assisted and provided by DharmaAI.',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: SacredTheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _verseList(List<Verse> verses) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 16),
      itemCount: verses.length,
      itemBuilder: (context, index) => VerseCard(verse: verses[index]),
    );
  }

  Widget _buildPremiumGate(BuildContext context, ScriptureBook book) {
    final textTheme = Theme.of(context).textTheme;
    final name = book == ScriptureBook.upanishads ? 'the Upanishads' : 'the Vedas';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories, size: 64,
                color: SacredTheme.templeGold.withOpacity(0.6)),
            const SizedBox(height: 20),
            Text('A Premium Scripture',
                style: textTheme.headlineSmall?.copyWith(
                    color: SacredTheme.headingColor(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Access to $name is part of the Sadhaka Premium and Annual paths.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star),
                label: const Text('UPGRADE TO UNLOCK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SacredTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                ),
              ),
            ),
          ],
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
                  Expanded(
                    child: Text(
                      '${verse.bookName == 'Bhagavad Gita' ? '' : '${verse.bookName} · '}'
                      '${AppTranslations.get('chapterLabel', currentLanguage)} ${verse.chapter}, ${AppTranslations.get('verseLabel', currentLanguage)} ${verse.verseNumber}',
                      style: textTheme.labelSmall?.copyWith(
                        color: SacredTheme.primary,
                        fontSize: (textTheme.labelSmall?.fontSize ?? 12) * textScale,
                      ),
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

              // Discreet source credit (Bhagavad Gita only)
              if (verse.bookName == 'Bhagavad Gita') ...[
                const SizedBox(height: 16),
                Text(
                  'Translation: Shri Purohit Swami (public domain) · Commentary: AI-assisted',
                  style: textTheme.labelSmall?.copyWith(
                    color: SacredTheme.outline,
                    fontSize: (textTheme.labelSmall?.fontSize ?? 11) * 0.9 * textScale,
                    height: 1.3,
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
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: SacredTheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close',
                ),
                const SizedBox(width: 12),
                Text(
                  AppTranslations.get('readingOptions', currentLanguage),
                  style: textTheme.headlineSmall?.copyWith(color: SacredTheme.headingColor(context)),
                ),
              ],
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
            child: Icon(icon, color: SacredTheme.headingColor(context), size: 18),
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
