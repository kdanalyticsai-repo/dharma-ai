import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/services/mock_scripture_data.dart';
import 'package:dharma_ai/screens/reader_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

class OfflineReaderScreen extends StatelessWidget {
  const OfflineReaderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Load cached Gita 2.47 shloka
    final Verse offlineVerse = MockScriptureData.gitaVerses[0];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Offline Reader', style: textTheme.headlineMedium?.copyWith(fontSize: 20)),
      ),
      body: MandalaBackground(
        scale: 0.9,
        alignment: Alignment.center,
        child: SafeArea(
          child: Column(
            children: [
              // Offline Alert Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: SacredTheme.error.withOpacity(0.08),
                  border: Border(
                    bottom: BorderSide(color: SacredTheme.error.withOpacity(0.2), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: SacredTheme.error, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Offline Mode Active. Displaying local vessel cache.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SacredTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),

              // Main Cached Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Bhagavad Gita 2.47',
                        style: textTheme.headlineMedium?.copyWith(
                          color: SacredTheme.headingColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pre-cached in your spiritual vault.',
                        style: textTheme.bodyMedium,
                      ),
                      const FadingDivider(height: 24),
                      
                      // Render cached verse card
                      VerseCard(verse: offlineVerse),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
