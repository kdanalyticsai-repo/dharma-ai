import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/language_provider.dart';

/// The DharmaAI brand lockup: the mark + "DharmaAI" wordmark image with a
/// crisp, separately-rendered tagline beneath it. Rendering the tagline as
/// real text (instead of baking it into the image) keeps it sharp and
/// legible at any size, and consistent everywhere the logo appears.
///
/// [height] is the height of the logo image (mark + wordmark). The tagline
/// scales proportionally. Falls back to styled text if the asset is missing.
class DharmaLogo extends ConsumerWidget {
  final double height;
  final bool showTagline;

  const DharmaLogo({Key? key, this.height = 120, this.showTagline = true})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = Image.asset(
      'assets/images/dharma_logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stack) => Text(
        'DharmaAI',
        textAlign: TextAlign.center,
        style: GoogleFonts.newsreader(
          fontSize: height * 0.5,
          fontWeight: FontWeight.w600,
          color: SacredTheme.headingColor(context),
        ),
      ),
    );

    if (!showTagline) return image;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        image,
        SizedBox(height: height * 0.10),
        Text(
          AppTranslations.get('logoTagline', ref.watch(languageProvider)),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: height * 0.155,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: SacredTheme.primary,
          ),
        ),
      ],
    );
  }
}
