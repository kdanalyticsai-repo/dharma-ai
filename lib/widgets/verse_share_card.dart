import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/providers/language_provider.dart';

/// The branded card that gets captured to a PNG and shared. Fixed width so the
/// rendered image is consistent; height wraps the content.
class VerseShareCard extends StatelessWidget {
  final Verse verse;
  final AppLanguage lang;
  const VerseShareCard({Key? key, required this.verse, required this.lang}) : super(key: key);

  String get _source {
    final book = verse.bookName == 'Bhagavad Gita'
        ? AppTranslations.get('bhagavadGita', lang)
        : verse.bookName;
    return '$book ${verse.chapter}.${verse.verseNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Fills the available width (no parent scale transform), so the capture
      // boundary renders 1:1 and toImage stays reliable on mobile.
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFDFB), Color(0xFFFAF1EA)],
        ),
        border: Border.all(color: SacredTheme.templeGold.withOpacity(0.35), width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/dharma_logo.png', height: 50),
          const SizedBox(height: 18),
          Text(
            AppTranslations.get('shlokaLabel', lang).toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: SacredTheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            verse.sanskritText.trim(),
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansDevanagari(
              fontSize: 18,
              height: 1.75,
              fontWeight: FontWeight.w500,
              color: SacredTheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Container(width: 60, height: 2, color: SacredTheme.templeGold.withOpacity(0.5)),
          const SizedBox(height: 18),
          Text(
            verse.getLocalizedTranslation(lang).trim(),
            textAlign: TextAlign.center,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.beVietnamPro(
              fontSize: 14.5,
              height: 1.55,
              color: SacredTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '— $_source',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: SacredTheme.primary,
            ),
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: SacredTheme.templeGold.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text(
            'DharmaAI',
            style: GoogleFonts.newsreader(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SacredTheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppTranslations.get('shareCardCta', lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.35,
              color: SacredTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'https://dharma.kdaanalytics.com/',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SacredTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
