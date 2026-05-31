import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';

/// The DharmaAI brand logo. Falls back to styled text if the image asset
/// (assets/images/dharma_logo.png) hasn't been added yet.
class DharmaLogo extends StatelessWidget {
  final double height;
  const DharmaLogo({Key? key, this.height = 120}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/dharma_logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) {
        return Text(
          'DharmaAI',
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            fontSize: height * 0.42,
            fontWeight: FontWeight.w600,
            color: SacredTheme.headingColor(context),
          ),
        );
      },
    );
  }
}
