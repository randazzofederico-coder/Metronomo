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

/// Registers [onShare] to receive share IDs delivered to an already-open
/// installed PWA via `launchQueue` (see web/index.html). Drains queued IDs.
void listenWebLaunchQueue(void Function(String shareId) onShare) {
  try {
    globalContext['_metronomoOnShare'] =
        ((JSString id) => onShare(id.toDart)).toJS;
    final pending = globalContext['_metronomoPendingShares'];
    if (pending != null) {
      final list = (pending as JSArray<JSString>).toDart;
      for (final id in list) {
        onShare(id.toDart);
      }
      globalContext['_metronomoPendingShares'] = <JSString>[].toJS;
    }
  } catch (_) {
    // launchQueue not supported — nothing to do.
  }
}

/// Whether the browser supports the Web Share API (`navigator.share`).
bool webCanShare() {
  try {
    final navigator = globalContext['navigator'] as JSObject;
    return navigator.has('share');
  } catch (_) {
    return false;
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
