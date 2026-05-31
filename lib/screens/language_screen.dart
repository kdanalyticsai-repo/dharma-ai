import 'package:flutter/material.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/screens/home_shell.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({Key? key}) : super(key: key);

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final List<Map<String, String>> _languages = [
    {'name': 'English', 'native': 'English', 'desc': 'Standard English transliteration and commentary'},
    {'name': 'Sanskrit', 'native': 'संस्कृतम्', 'desc': 'Devanagari text and phonetic transliteration'},
    {'name': 'Hindi', 'native': 'हिन्दी', 'desc': 'Hindi translation and detailed commentaries'},
    {'name': 'Tamil', 'native': 'தமிழ்', 'desc': 'Tamil script translations and verses'},
    {'name': 'Telugu', 'native': 'తెలుగు', 'desc': 'Telugu script translations and verses'},
  ];

  int? _selectedLanguageIndex = 0; // Default to English

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: MandalaBackground(
        scale: 1.0,
        alignment: Alignment.topLeft,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: SacredTheme.stackMd),
                
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                
                const SizedBox(height: SacredTheme.stackMd),
                
                // Title
                Text(
                  'Choose Language',
                  style: textTheme.headlineLarge?.copyWith(
                    color: SacredTheme.headingColor(context),
                  ),
                ),
                const SizedBox(height: SacredTheme.stackSm),
                Text(
                  'Select your preferred language for scripture readings, translations, and AI chat feedback.',
                  style: textTheme.bodyMedium,
                ),
                
                const SizedBox(height: SacredTheme.stackLg),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedLanguageIndex == index;
                      final lang = _languages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: SacredTheme.stackSm),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedLanguageIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SacredTheme.surfaceContainer
                                  : SacredTheme.surfaceContainerLowest,
                              border: Border.all(
                                width: isSelected ? 1.5 : 0.5,
                                color: isSelected
                                    ? SacredTheme.primary
                                    : SacredTheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                            ),
                            child: Row(
                              children: [
                                // Left side Language circle indicator
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? SacredTheme.primary.withOpacity(0.1)
                                        : SacredTheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      lang['name']![0],
                                      style: textTheme.labelLarge?.copyWith(
                                        color: isSelected
                                            ? SacredTheme.primary
                                            : SacredTheme.onSurfaceVariant,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Text Descriptions
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            lang['name']!,
                                            style: textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? SacredTheme.primary
                                                  : SacredTheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '(${lang['native']})',
                                            style: textTheme.bodyMedium?.copyWith(
                                              color: SacredTheme.outline,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        lang['desc']!,
                                        style: textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w400,
                                          color: SacredTheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Radio check
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? SacredTheme.primary
                                      : SacredTheme.outlineVariant,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeShell(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text('ENTER SACRED SPACE'),
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
}
