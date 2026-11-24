import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'file_export_io.dart'
    if (dart.library.js_interop) 'file_export_web.dart';

/// How the exported file was handed off to the user.
enum FileExportOutcome { downloaded, shared }

/// Exports raw [bytes] as a named file ([fileName]) using a browser download on
/// web/PWA or the native share sheet on mobile/desktop.
Future<FileExportOutcome> exportBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? shareTitle,
  Rect? shareOrigin,
}) async {
  final downloaded = await exportFileBytesImpl(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
    shareTitle: shareTitle,
    shareOrigin: shareOrigin,
  );
  return downloaded ? FileExportOutcome.downloaded : FileExportOutcome.shared;
}
