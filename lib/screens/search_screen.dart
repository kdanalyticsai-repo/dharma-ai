import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/screens/reader_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/lotus_painter.dart';
import 'package:dharma_ai/providers/language_provider.dart';

class ScriptureSearchScreen extends ConsumerWidget {
  const ScriptureSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);

    final controller = TextEditingController(text: query);
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
              child: Text(
                AppTranslations.get('scriptureSearch', currentLanguage),
                style: textTheme.headlineLarge?.copyWith(
                  color: SacredTheme.headingColor(context),
                ),
              ),
            ),
            const FadingDivider(height: 12),

            // Search Text Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 8),
              child: TextField(
                controller: controller,
                onChanged: (val) {
                  ref.read(searchQueryProvider.notifier).state = val;
                },
                decoration: InputDecoration(
                  hintText: AppTranslations.get('searchPlaceholder', currentLanguage),
                  hintStyle: textTheme.bodyMedium?.copyWith(color: SacredTheme.outline),
                  prefixIcon: const Icon(Icons.search, color: SacredTheme.outline),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: SacredTheme.outline),
                          onPressed: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: SacredTheme.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                    borderSide: const BorderSide(color: SacredTheme.outlineVariant, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                    borderSide: BorderSide(color: SacredTheme.headingColor(context), width: 1.5),
                  ),
                ),
                style: textTheme.bodyLarge,
              ),
            ),

            // Search Results List
            Expanded(
              child: query.trim().isEmpty
                  ? const SearchEmptyState()
                  : resultsAsync.when(
                      data: (results) {
                        if (results.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                AppTranslations.get('searchNoResults', currentLanguage),
                                style: textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: SacredTheme.marginEdge,
                            vertical: 16,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final verse = results[index];
                            final localizedBookName = verse.bookName == 'Bhagavad Gita'
                                ? AppTranslations.get('bhagavadGita', currentLanguage)
                                : verse.bookName;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  // Open details in a full view
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SingleVerseDetailScreen(verse: verse),
                                    ),
                                  );
                                },
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$localizedBookName • ${AppTranslations.get('chapterLabel', currentLanguage)} ${verse.chapter}, ${AppTranslations.get('verseLabel', currentLanguage)} ${verse.verseNumber}',
                                          style: textTheme.labelSmall?.copyWith(color: SacredTheme.primary),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          verse.getLocalizedTranslation(currentLanguage),
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: SacredTheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: LotusLoadingIndicator(size: 60),
                      ),
                      error: (err, stack) => Center(
                        child: Text('${AppTranslations.get('searchError', currentLanguage)}: $err'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchEmptyState extends ConsumerWidget {
  const SearchEmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.manage_search,
              size: 72,
              color: SacredTheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('searchEmptyTitle', currentLanguage),
              style: textTheme.headlineSmall?.copyWith(color: SacredTheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.get('searchEmptyDesc', currentLanguage),
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SingleVerseDetailScreen extends ConsumerWidget {
  final Verse verse;

  const SingleVerseDetailScreen({Key? key, required this.verse}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${AppTranslations.get('chapterLabel', currentLanguage)} ${verse.chapter}, ${AppTranslations.get('verseLabel', currentLanguage)} ${verse.verseNumber}',
          style: textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
          child: VerseCard(verse: verse),
        ),
      ),
    );
  }
}
