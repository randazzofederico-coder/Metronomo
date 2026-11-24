import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Web/PWA implementation: creates a `Blob` URL and triggers a browser file
/// download via a temporary `<a download="...">` element.
Future<bool> exportFileBytesImpl({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? shareTitle,
  Rect? shareOrigin,
}) async {
  final blobCtor = globalContext['Blob'] as JSFunction;
  final parts = <JSAny>[bytes.toJS].toJS;
  final bag = JSObject()..['type'] = mimeType.toJS;
  final blob = blobCtor.callAsConstructor<JSObject>(parts, bag);

  final urlApi = globalContext['URL'] as JSObject;
  final objectUrl = urlApi.callMethod<JSString>('createObjectURL'.toJS, blob);

  final document = globalContext['document'] as JSObject;
  final anchor = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  anchor['href'] = objectUrl;
  anchor['download'] = fileName.toJS;
  final style = anchor['style'] as JSObject;
  style['display'] = 'none'.toJS;

  final body = document['body'] as JSObject?;
  body?.callMethod<JSAny?>('appendChild'.toJS, anchor);
  anchor.callMethod<JSAny?>('click'.toJS);
  body?.callMethod<JSAny?>('removeChild'.toJS, anchor);

  Timer(const Duration(seconds: 1), () {
    try {
      urlApi.callMethod<JSAny?>('revokeObjectURL'.toJS, objectUrl);
    } catch (_) {
      // Ignore cleanup errors if the page is unloading.
    }
  });
  return true;
}
