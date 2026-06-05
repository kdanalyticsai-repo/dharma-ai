import 'dart:typed_data';

/// Non-web fallback. On mobile/desktop we use the native share sheet instead of
/// a browser download, so this is a no-op.
void saveImageBytes(Uint8List bytes, String filename) {}
