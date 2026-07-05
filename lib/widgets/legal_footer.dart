import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dharma_ai/theme/theme.dart';

/// Footer with links to the legal pages (served as static pages on the web
/// app). Uses absolute URLs so it works on web and, later, the Android app.
class LegalFooter extends StatelessWidget {
  const LegalFooter({Key? key}) : super(key: key);

  static const String _base = 'https://dharma.kdaanalytics.com';

  Future<void> _open(String page) async {
    final uri = Uri.parse('$_base/$page');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetector + padding gives a larger, reliable tap area (InkWell
    // can miss taps on small text inside bottom sheets on Android).
    Widget link(String label, String page) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(page),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: SacredTheme.onSurfaceVariant,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
    Widget dot() => Text('·',
        style: GoogleFonts.inter(fontSize: 11, color: SacredTheme.outline));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          link('Privacy', 'privacy.html'),
          dot(),
          link('Terms', 'terms.html'),
          dot(),
          link('Refunds', 'refunds.html'),
          dot(),
          link('Contact', 'contact.html'),
        ],
      ),
    );
  }
}
