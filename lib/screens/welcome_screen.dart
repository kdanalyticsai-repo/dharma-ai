import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/widgets/dharma_logo.dart';
import 'package:dharma_ai/screens/login_screen.dart';
import 'package:dharma_ai/providers/language_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);

    return Scaffold(
      body: MandalaBackground(
        scale: 1.1,
        alignment: Alignment.center,
        rotate: true,
        opacity: 0.14,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 12),
                
                // Top Branding / Logo Zone
                Column(
                  children: [
                    const DharmaLogo(height: 132),
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 1,
                      color: SacredTheme.templeGold,
                    ),
                  ],
                ),

                // Language Selection Bar
                Column(
                  children: [
                    Text(
                      AppTranslations.get('selectLanguage', currentLanguage).toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: SacredTheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: AppLanguage.values.map((lang) {
                        final isSelected = currentLanguage == lang;
                        return InkWell(
                          onTap: () {
                            ref.read(languageProvider.notifier).setLanguage(lang);
                          },
                          borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SacredTheme.primary
                                  : SacredTheme.surfaceContainerLowest,
                              border: Border.all(
                                color: isSelected
                                    ? SacredTheme.primary
                                    : SacredTheme.outlineVariant,
                                width: isSelected ? 1.0 : 0.5,
                              ),
                              borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                            ),
                            child: Text(
                              lang.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? Colors.white : SacredTheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Center Daily Reflection Card (Shloka)
                Card(
                  color: SacredTheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
                    side: const BorderSide(color: SacredTheme.templeGold, width: 1.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.spa_outlined, color: SacredTheme.templeGold, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              AppTranslations.get('shlokaLabel', currentLanguage),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: SacredTheme.primary,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.spa_outlined, color: SacredTheme.templeGold, size: 14),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppTranslations.get('shlokaVerse', currentLanguage),
                          style: GoogleFonts.newsreader(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: SacredTheme.deepMeditativeIndigo,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: SacredTheme.outlineVariant, thickness: 0.5),
                        const SizedBox(height: 8),
                        Text(
                          AppTranslations.get('shlokaTranslation', currentLanguage),
                          style: GoogleFonts.newsreader(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: SacredTheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Content & Call to Action
                Column(
                  children: [
                    Text(
                      AppTranslations.get('seekDivineWisdom', currentLanguage),
                      style: textTheme.headlineMedium?.copyWith(
                        color: SacredTheme.primary,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppTranslations.get('welcomeSubtitle', currentLanguage),
                      style: textTheme.bodyLarge?.copyWith(
                        color: SacredTheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Call to Action
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(startInSignUpMode: true),
                            ),
                          );
                        },
                        child: Text(AppTranslations.get('beginYourPath', currentLanguage)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(startInSignUpMode: false),
                          ),
                        );
                      },
                      child: Text(
                        'Already on the path? Sign in',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SacredTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: SacredTheme.safeAreaBottom),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
