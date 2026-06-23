import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dharma_ai/theme/theme.dart';

/// Footer with links to the legal pages (served as static pages on the web
/// app). Uses absolute URLs so it works on web and, later, the Android app.
class LegalFooter extends StatelessWidget {
  const LegalFooter({Key? key}) : super(key: key);

  static const String _base = 'https://dharma.kdaanalytics.com';

  void _open(String page) {
    launchUrl(Uri.parse('$_base/$page'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    Widget link(String label, String page) => InkWell(
          onTap: () => _open(page),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: SacredTheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
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
          link('Web App', ''),
          dot(),
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
