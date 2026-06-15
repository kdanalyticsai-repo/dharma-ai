import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/screens/home_shell.dart';
import 'package:dharma_ai/providers/auth_provider.dart' show isNewUserOnboarding;
import 'package:dharma_ai/providers/language_provider.dart';

class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  int? _selectedGoalIndex;
  int? _selectedLevelIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);

    // Retrieve localized goals and familiarity levels
    final List<String> goals = List.generate(
      5,
      (index) => AppTranslations.get('goal$index', currentLanguage),
    );

    final List<String> levels = List.generate(
      3,
      (index) => AppTranslations.get('level$index', currentLanguage),
    );

    return Scaffold(
      body: MandalaBackground(
        scale: 1.0,
        alignment: Alignment.topRight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                
                const SizedBox(height: 8),
                
                // Title
                Text(
                  AppTranslations.get('personalizeTitle', currentLanguage),
                  style: textTheme.headlineLarge?.copyWith(
                    color: SacredTheme.headingColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTranslations.get('personalizeSubtitle', currentLanguage),
                  style: textTheme.bodyMedium,
                ),
                
                const SizedBox(height: 12),
                
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Spiritual Goal
                          Text(
                            AppTranslations.get('primaryGoal', currentLanguage),
                            style: textTheme.labelSmall?.copyWith(
                              color: SacredTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(goals.length, (index) {
                            final isSelected = _selectedGoalIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: SacredTheme.stackSm),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedGoalIndex = index;
                                  });
                                  // Scroll to reveal the familiarity section
                                  if (_selectedLevelIndex == null) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (_scrollController.hasClients) {
                                        _scrollController.animateTo(
                                          _scrollController.position.maxScrollExtent,
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
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
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: SacredTheme.primary.withOpacity(0.05),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: isSelected
                                            ? SacredTheme.primary
                                            : SacredTheme.outline,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          goals[index],
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                            color: isSelected
                                                ? SacredTheme.primary
                                                : SacredTheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 12),

                          // Section 2: Experience Level
                          Text(
                            AppTranslations.get('scriptureFamiliarity', currentLanguage),
                            style: textTheme.labelSmall?.copyWith(
                              color: SacredTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(levels.length, (index) {
                            final isSelected = _selectedLevelIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: SacredTheme.stackSm),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedLevelIndex = index;
                                  });
                                },
                                borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
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
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: SacredTheme.primary.withOpacity(0.05),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.radio_button_off,
                                        color: isSelected
                                            ? SacredTheme.primary
                                            : SacredTheme.outline,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          levels[index],
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                            color: isSelected
                                                ? SacredTheme.primary
                                                : SacredTheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Next Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selectedGoalIndex != null && _selectedLevelIndex != null)
                        ? () {
                            isNewUserOnboarding = false;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomeShell(),
                              ),
                              (route) => false,
                            );
                          }
                        : null, // Disabled until selections are made
                    child: Text(AppTranslations.get('continueBtn', currentLanguage)),
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
