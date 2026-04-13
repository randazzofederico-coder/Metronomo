import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Reads the ?share= parameter from the current browser URL.
String? getShareParamFromUrl() {
  try {
    final location = globalContext['location'] as JSObject;
    final search = (location['search'] as JSString).toDart;
    if (search.isEmpty) return null;

    // Parse just the query string (remove leading '?')
    final queryString = search.startsWith('?') ? search.substring(1) : search;
    final uri = Uri(query: queryString);
    return uri.queryParameters['share'];
  } catch (_) {
    return null;
  }
}

/// Removes all query parameters from the browser URL
/// using history.replaceState (no page reload).
void cleanShareParamFromUrl() {
  try {
    final location = globalContext['location'] as JSObject;
    final origin = (location['origin'] as JSString).toDart;
    final pathname = (location['pathname'] as JSString).toDart;
    final hash = (location['hash'] as JSString).toDart;

    // Reconstruct URL without query params
    final cleanUrl = '$origin$pathname$hash';

    final history = globalContext['history'] as JSObject;
    history.callMethod<JSAny?>(
      'replaceState'.toJS,
      null,           // state
      ''.toJS,        // title
      cleanUrl.toJS,  // url
    );
  } catch (_) {
    // Silently fail if history API is not available
  }
}
