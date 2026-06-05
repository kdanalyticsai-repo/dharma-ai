import 'dart:html' as html;
import 'dart:typed_data';

/// Web: trigger a browser download of the PNG bytes (used as the desktop
/// fallback when the Web Share API can't share files).
void saveImageBytes(Uint8List bytes, String filename) {
  final blob = html.Blob(<dynamic>[bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
