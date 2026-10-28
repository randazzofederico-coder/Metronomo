import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web-specific reload: unregisters service workers, clears caches,
/// and performs a hard reload so the browser downloads the latest build.
Future<void> performWebReload() async {
  try {
    // 1. Unregister all service workers so stale cache is not served.
    final navigator = globalContext['navigator'] as JSObject;
    final sw = navigator['serviceWorker'];
    if (sw != null) {
      final registrations = await (sw as JSObject)
          .callMethod<JSPromise>('getRegistrations'.toJS)
          .toDart;
      final list = registrations as JSArray;
      for (int i = 0; i < list.length; i++) {
        (list[i] as JSObject).callMethod<JSAny?>('unregister'.toJS);
      }
    }
  } catch (_) {
    // Service worker API might not be available — ignore.
  }

  try {
    // 2. Clear all Cache Storage entries.
    final caches = globalContext['caches'];
    if (caches != null) {
      final keys = await (caches as JSObject)
          .callMethod<JSPromise>('keys'.toJS)
          .toDart;
      final keyList = keys as JSArray;
      for (int i = 0; i < keyList.length; i++) {
        (caches as JSObject).callMethod<JSAny?>(
          'delete'.toJS,
          keyList[i],
        );
      }
    }
  } catch (_) {
    // Cache API might not be available — ignore.
  }

  // 3. Hard reload the page.
  final location = globalContext['location'] as JSObject;
  location.callMethod<JSAny?>('reload'.toJS);
}
