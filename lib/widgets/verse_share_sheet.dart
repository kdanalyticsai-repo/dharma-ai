import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/widgets/verse_share_card.dart';
// Conditional: web triggers a browser download; other platforms no-op (share only).
import 'package:dharma_ai/services/image_saver_io.dart'
    if (dart.library.html) 'package:dharma_ai/services/image_saver_web.dart';

/// Opens a bottom sheet previewing the branded verse card with Share / Save.
void openVerseShareSheet(BuildContext context, Verse verse, AppLanguage lang) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: SacredTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _VerseShareSheet(verse: verse, lang: lang),
  );
}

class _VerseShareSheet extends StatefulWidget {
  final Verse verse;
  final AppLanguage lang;
  const _VerseShareSheet({required this.verse, required this.lang});

  @override
  State<_VerseShareSheet> createState() => _VerseShareSheetState();
}

class _VerseShareSheetState extends State<_VerseShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  // Capture the PNG once when the sheet opens. Pre-capturing is essential: the
  // mobile Web Share API requires the share() call to happen *inside* the tap
  // gesture (user activation). Awaiting toImage on tap loses that activation, so
  // we await it here (at open) and share synchronously on tap.
  Uint8List? _bytes;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureOnce());
  }

  Future<void> _captureOnce() async {
    // Give the logo image + Devanagari fonts a frame or two to paint.
    await Future.delayed(const Duration(milliseconds: 400));
    Uint8List? bytes;
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('verse share capture error: $e');
    }
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _ready = bytes != null;
      _failed = bytes == null;
    });
  }

  // NOT async and NOT awaited before share() — keeps user activation on mobile.
  void _share() {
    final bytes = _bytes;
    if (bytes == null) return;
    final caption =
        '${AppTranslations.get('shareVerseCaption', widget.lang)}\nhttps://dharma.kdaanalytics.com';
    Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'image/png', name: 'dharma-verse.png')],
      text: caption,
    ).then((_) {}, onError: (Object _) {
      // Browser can't share files (e.g. desktop) → download instead.
      saveImageBytes(bytes, 'dharma-verse.png');
    });
  }

  void _save() {
    final bytes = _bytes;
    if (bytes != null) saveImageBytes(bytes, 'dharma-verse.png');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = widget.lang;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: SacredTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppTranslations.get('shareVerseTitle', lang),
                style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: SacredTheme.primary),
              ),
              const SizedBox(height: 16),
              // Preview — scaled to fit width; captured at full resolution.
              Flexible(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: VerseShareCard(verse: widget.verse, lang: lang),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppTranslations.get('shareVerseFailed', lang),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: SacredTheme.error),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _ready ? _save : null,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(AppTranslations.get('shareVerseSave', lang)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SacredTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _ready ? _share : null,
                        icon: _ready
                            ? const Icon(Icons.ios_share_rounded, size: 18)
                            : const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                        label: Text(AppTranslations.get('shareVerseShare', lang)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
