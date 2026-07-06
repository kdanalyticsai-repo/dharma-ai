import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/widgets/rotating_chakra.dart';
import 'package:dharma_ai/widgets/dharma_logo.dart';

const _prefKey = 'onboarding_v1_shown';

Future<void> maybeShowOnboarding(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefKey) == true) return;
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const OnboardingScreen(),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );
  await prefs.setBool(_prefKey, true);
}

// ── Per-slide data ────────────────────────────────────────────────────────────

class _OnboardingPage {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final Color accentColor;
  final String? hintKey;

  const _OnboardingPage({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.accentColor,
    this.hintKey,
  });
}

// Slide 0 is the language picker (special). Slides 1-4 are these content pages.
const _pages = [
  _OnboardingPage(
    icon: Icons.auto_awesome,
    titleKey: 'onboarding1Title',
    subtitleKey: 'onboarding1Subtitle',
    accentColor: Color(0xFFE8C84A),
  ),
  _OnboardingPage(
    icon: Icons.menu_book_outlined,
    titleKey: 'onboarding2Title',
    subtitleKey: 'onboarding2Subtitle',
    accentColor: Color(0xFF5ABCA2),
    hintKey: 'onboarding2Hint',
  ),
  _OnboardingPage(
    icon: Icons.self_improvement,
    titleKey: 'onboarding3Title',
    subtitleKey: 'onboarding3Subtitle',
    accentColor: Color(0xFFB07EC0),
    hintKey: 'onboarding3Hint',
  ),
  _OnboardingPage(
    icon: Icons.spa_outlined,
    titleKey: 'onboarding4Title',
    subtitleKey: 'onboarding4Subtitle',
    accentColor: Color(0xFFCC6B1A),
    hintKey: 'onboarding4Hint',
  ),
];

// Total page count = 1 language slide + 4 content slides
const _totalPages = 5;

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLangSlide => _page == 0;
  bool get _isLastSlide => _page == _totalPages - 1;

  // Accent for language slide is celestial blue; content slides use their own color.
  Color get _accent =>
      _isLangSlide ? const Color(0xFF6AADDE) : _pages[_page - 1].accentColor;

  void _goTo(int i) => _controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  void _next() => _isLastSlide ? _done() : _goTo(_page + 1);

  void _done() => Navigator.pop(context);

  // Called when user taps a language on slide 0 — saves it and advances.
  Future<void> _selectLanguage(AppLanguage lang) async {
    await ref.read(languageProvider.notifier).setLanguage(lang);
    if (mounted) _goTo(1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final screenW = MediaQuery.of(context).size.width;
    final accent = _accent;

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ───────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0B2E),
                  Color(0xFF1C1560),
                  Color(0xFF0B1A30),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Rotating Dharmachakra ─────────────────────────────────────────
          Center(
            child: Opacity(
              opacity: 0.13,
              child: ColorFiltered(
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                child: RotatingChakra(
                  size: screenW * 0.90,
                  spokes: 12,
                  period: const Duration(seconds: 72),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Logo + Skip row
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ColorFiltered(
                        colorFilter:
                            ColorFilter.mode(accent, BlendMode.srcIn),
                        child: const DharmaLogo(
                            height: 72, showTagline: false),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _done,
                          child: Text(
                            _isLangSlide
                                ? 'Skip'
                                : AppTranslations.get(
                                    'onboardingSkip', lang),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Tagline — right-padded 40px so optical center aligns with D mark
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      AppTranslations.get('logoTagline', lang),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: accent.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Slides (0 = language picker, 1-4 = content)
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _totalPages,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _LanguageSlide(
                          accent: accent,
                          currentLang: lang,
                          onSelect: _selectLanguage,
                        );
                      }
                      return _PageContent(
                          page: _pages[i - 1], lang: lang);
                    },
                  ),
                ),

                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (i) {
                    final active = i == _page;
                    final dotColor =
                        i == 0 ? const Color(0xFF6AADDE) : _pages[i - 1].accentColor;
                    return GestureDetector(
                      onTap: () => _goTo(i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? dotColor : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: dotColor.withOpacity(0.55),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),

                // Next / Begin button — hidden on language slide
                if (!_isLangSlide)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: _GlowButton(
                      label: _isLastSlide
                          ? AppTranslations.get('onboardingBegin', lang)
                          : AppTranslations.get('onboardingNext', lang),
                      color: accent,
                      onTap: _next,
                    ),
                  ),

                // Spacer keeps layout stable whether button is shown or not
                SizedBox(height: _isLangSlide ? 72 : 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 0: Language picker ──────────────────────────────────────────────────

class _LanguageSlide extends StatelessWidget {
  final Color accent;
  final AppLanguage currentLang;
  final ValueChanged<AppLanguage> onSelect;

  const _LanguageSlide({
    required this.accent,
    required this.currentLang,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.10),
              border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.35),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(Icons.language, size: 42, color: accent),
          ),

          const SizedBox(height: 28),

          // Title — shown in all supported languages so it's self-explanatory
          Text(
            'Choose Your Language',
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'भाषा चुनें  •  மொழி தேர்வு  •  ভাষা বেছে নিন  •  ભાષા પસંદ કરો  •  ଭାଷା ବାଛନ୍ତୁ',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white54,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 32),

          // Language grid — capped width so tiles stay compact on desktop
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.2,
                physics: const NeverScrollableScrollPhysics(),
                children: AppLanguage.values.map((l) {
                  final selected = l == currentLang;
                  return GestureDetector(
                    onTap: () => onSelect(l),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withOpacity(0.20)
                            : Colors.white.withOpacity(0.05),
                        borderRadius:
                            BorderRadius.circular(SacredTheme.radiusDefault),
                        border: Border.all(
                          color: selected
                              ? accent
                              : Colors.white.withOpacity(0.15),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          l.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected ? accent : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tap hint
          Text(
            'Tap a language to continue  →',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content slide ─────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final AppLanguage lang;

  const _PageContent({required this.page, required this.lang});

  @override
  Widget build(BuildContext context) {
    final title = AppTranslations.get(page.titleKey, lang);
    final subtitle = AppTranslations.get(page.subtitleKey, lang);
    final hint =
        page.hintKey != null ? AppTranslations.get(page.hintKey!, lang) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.accentColor.withOpacity(0.10),
              border: Border.all(
                  color: page.accentColor.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: page.accentColor.withOpacity(0.35),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(page.icon, size: 54, color: page.accentColor),
          ),

          const SizedBox(height: 36),

          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.65,
            ),
          ),

          if (hint != null) ...[
            const SizedBox(height: 22),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: page.accentColor.withOpacity(0.10),
                borderRadius:
                    BorderRadius.circular(SacredTheme.radiusDefault),
                border: Border.all(
                    color: page.accentColor.withOpacity(0.35), width: 1),
              ),
              child: Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: page.accentColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Glowing button ────────────────────────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlowButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0E0B2E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
