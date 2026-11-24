import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// Mobile/desktop implementation: hands off the generated file to the OS share
/// sheet (Save to Files / Drive / DAW / email / messaging).
Future<bool> exportFileBytesImpl({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? shareTitle,
  Rect? shareOrigin,
}) async {
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
    fileNameOverrides: [fileName],
    subject: shareTitle,
    title: shareTitle,
    sharePositionOrigin: shareOrigin,
  ));
  return false;
}
