import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dharma_ai/services/pwa_install_service.dart';
import 'package:dharma_ai/theme/theme.dart';

/// Shows an "Install App" button on web when the browser's PWA install prompt
/// is available (Android Chrome). Hidden on iOS (no beforeinstallprompt API)
/// and invisible on non-web platforms.
class PwaInstallButton extends StatefulWidget {
  const PwaInstallButton({Key? key}) : super(key: key);

  @override
  State<PwaInstallButton> createState() => _PwaInstallButtonState();
}

class _PwaInstallButtonState extends State<PwaInstallButton> {
  bool _available = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _available = pwaInstallAvailable;
    // Poll since beforeinstallprompt can fire before or after Flutter init.
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final v = pwaInstallAvailable;
      if (v != _available && mounted) setState(() => _available = v);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_available) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () {
        pwaInstall();
        setState(() => _available = false);
      },
      icon: const Icon(Icons.download_rounded, size: 16),
      label: const Text('Install App'),
      style: OutlinedButton.styleFrom(
        foregroundColor: SacredTheme.primary,
        side: const BorderSide(color: SacredTheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
