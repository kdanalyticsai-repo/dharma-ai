import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/services/banner_storage_stub.dart'
    if (dart.library.html) 'package:dharma_ai/services/banner_storage_web.dart';

// Flip to true the day the Android app goes live on the Play Store.
const bool _appLiveOnPlayStore = false;

const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.kdaanalytics.dharmaai';

/// A dismissible bottom banner shown to Android mobile browser users on the
/// web app, directing them to install the native app from the Play Store.
///
/// Only renders when [_appLiveOnPlayStore] is true, kIsWeb is true,
/// the visitor is on an Android browser, and the user hasn't dismissed it.
class AppDownloadBanner extends StatefulWidget {
  const AppDownloadBanner({Key? key}) : super(key: key);

  @override
  State<AppDownloadBanner> createState() => _AppDownloadBannerState();
}

class _AppDownloadBannerState extends State<AppDownloadBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || !_appLiveOnPlayStore) return;
    if (isMobileAndroidBrowser() && !getBannerDismissed()) {
      setState(() => _visible = true);
    }
  }

  void _dismiss() {
    setBannerDismissed();
    setState(() => _visible = false);
  }

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Container(
      color: SacredTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Image.asset(
              'assets/images/dharma_logo.png',
              height: 36,
              color: SacredTheme.onPrimary,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, __, ___) => const SizedBox(width: 36),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DharmaAI',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: SacredTheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    'Better on the app',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SacredTheme.onPrimary.withOpacity(0.85),
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openPlayStore,
              style: TextButton.styleFrom(
                backgroundColor: SacredTheme.onPrimary,
                foregroundColor: SacredTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Get App',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _dismiss,
              child: Icon(Icons.close, color: SacredTheme.onPrimary.withOpacity(0.8), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
