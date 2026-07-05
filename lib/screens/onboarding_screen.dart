import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/widgets/rotating_chakra.dart';

const _prefKey = 'onboarding_v1_shown';

/// Call this from HomeShell.initState (via addPostFrameCallback).
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.auto_awesome,
      title: 'Welcome to DharmaAI',
      subtitle: 'Your personal gateway to Vedic wisdom — ancient teachings, made alive for your daily life.',
      accentColor: Color(0xFFD4AF37),
    ),
    _OnboardingPage(
      icon: Icons.menu_book_outlined,
      title: 'Ask the Gita Anything',
      subtitle: 'Our Scripture Scholar has read all 18 chapters of the Bhagavad Gita. Get verse-backed answers to your deepest questions.',
      accentColor: Color(0xFF7C9EBA),
      tabHint: 'Find it under the Wisdom tab ↓',
    ),
    _OnboardingPage(
      icon: Icons.self_improvement,
      title: 'Your AI Guru',
      subtitle: 'Have a continuous spiritual conversation. Your Guru remembers your journey and offers guidance tailored to you.',
      accentColor: Color(0xFF9B8EC4),
      tabHint: 'Find it under the AI Guru tab ↓',
    ),
    _OnboardingPage(
      icon: Icons.spa_outlined,
      title: 'Build a Daily Sadhana',
      subtitle: 'Log meditation, chanting, and verse reading every day. Build streaks and watch your practice deepen over time.',
      accentColor: Color(0xFF6BAA8E),
      tabHint: 'Find it under the Sadhana tab ↓',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
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
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: SacredTheme.deepMeditativeIndigo,
      body: Stack(
        children: [
          // Large rotating Dharmachakra — full-bleed background, same as login
          Center(
            child: Opacity(
              opacity: 0.11,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                child: RotatingChakra(
                  size: MediaQuery.of(context).size.width * 0.88,
                  spokes: 12,
                  period: const Duration(seconds: 72),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _done,
                    child: Text('Skip',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: Colors.white60)),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _PageContent(page: _pages[i]),
                  ),
                ),

                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? SacredTheme.templeGold : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 28),

                // Next / Get Started button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SacredTheme.templeGold,
                        foregroundColor: SacredTheme.deepMeditativeIndigo,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
                        elevation: 0,
                      ),
                      child: Text(
                        isLast ? 'Begin Your Journey' : 'Next',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
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

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow ring
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.accentColor.withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: page.accentColor.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(page.icon, size: 52, color: page.accentColor),
          ),

          const SizedBox(height: 40),

          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white70,
              height: 1.6,
            ),
          ),

          if (page.tabHint != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: page.accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                border: Border.all(color: page.accentColor.withOpacity(0.3)),
              ),
              child: Text(
                page.tabHint!,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: page.accentColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final String? tabHint;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.tabHint,
  });
}
