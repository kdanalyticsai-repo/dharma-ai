import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/widgets/rotating_chakra.dart';
import 'package:dharma_ai/widgets/dharma_logo.dart';

const _prefKey = 'onboarding_v1_shown';

/// Call from HomeShell / WelcomeScreen initState (via addPostFrameCallback).
/// Shows the onboarding carousel once, then marks it done.
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

// ── Per-slide data (stores translation keys, not raw strings) ─────────────────

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

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  void _goTo(int i) => _controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  void _next() {
    if (_page < _pages.length - 1) {
      _goTo(_page + 1);
    } else {
      _done();
    }
  }

  void _done() => Navigator.pop(context);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isLast = _page == _pages.length - 1;
    final accent = _pages[_page].accentColor;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // ── Rich gradient background ──────────────────────────────────────
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

          // ── Large rotating Dharmachakra ───────────────────────────────────
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

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Logo + skip row
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Logo tinted to current slide accent
                      ColorFiltered(
                        colorFilter:
                            ColorFilter.mode(accent, BlendMode.srcIn),
                        child: const DharmaLogo(
                            height: 52, showTagline: false),
                      ),
                      // Skip — pinned right
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _done,
                          child: Text(
                            AppTranslations.get('onboardingSkip', lang),
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

                // Tagline
                Text(
                  AppTranslations.get('onboardingTagline', lang),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: accent.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 8),

                // Slides
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) =>
                        _PageContent(page: _pages[i], lang: lang),
                  ),
                ),

                // ── Clickable dot indicators ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _page;
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
                            color: active ? accent : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: accent.withOpacity(0.55),
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

                // ── Next / Begin button ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _GlowButton(
                    label: isLast
                        ? AppTranslations.get('onboardingBegin', lang)
                        : AppTranslations.get('onboardingNext', lang),
                    color: accent,
                    onTap: _next,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide content ─────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final AppLanguage lang;

  const _PageContent({required this.page, required this.lang});

  @override
  Widget build(BuildContext context) {
    final title = AppTranslations.get(page.titleKey, lang);
    final subtitle = AppTranslations.get(page.subtitleKey, lang);
    final hint = page.hintKey != null
        ? AppTranslations.get(page.hintKey!, lang)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow ring
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
