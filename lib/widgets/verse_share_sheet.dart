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
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('verse share capture error: $e');
      return null;
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await _capture();
    if (bytes != null) {
      final caption =
          '${AppTranslations.get('shareVerseCaption', widget.lang)}\nhttps://dharma.kdaanalytics.com';
      try {
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: 'dharma-verse.png')],
          text: caption,
        );
      } catch (_) {
        // Browser can't share files (e.g. desktop) → download instead.
        saveImageBytes(bytes, 'dharma-verse.png');
      }
    } else {
      _snack();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await _capture();
    if (bytes != null) {
      saveImageBytes(bytes, 'dharma-verse.png');
    } else {
      _snack();
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTranslations.get('shareVerseFailed', widget.lang))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = widget.lang;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
            // Preview (scaled to fit) — captured at full resolution regardless.
            Flexible(
              child: SingleChildScrollView(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: VerseShareCard(verse: widget.verse, lang: lang),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _save,
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
                    onPressed: _busy ? null : _share,
                    icon: _busy
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(AppTranslations.get('shareVerseShare', lang)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
