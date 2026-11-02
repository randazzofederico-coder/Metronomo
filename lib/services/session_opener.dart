import 'package:flutter/widgets.dart';

import '../models/session_model.dart';

/// Lets pushed screens (playlist editor / player) open a library session in
/// "Tocar" as the active session, exactly like opening it from the library.
///
/// [HomeShell] registers the handler; [open] first pops every pushed route
/// (the playlist player restores the previous Tocar state when it closes)
/// and then hands the session over, which protects unsaved changes as usual.
class SessionOpener {
  SessionOpener._();

  static Future<bool> Function(Session session)? _handler;

  static void register(Future<bool> Function(Session session) handler) => _handler = handler;

  static void unregister(Future<bool> Function(Session session) handler) {
    if (identical(_handler, handler)) _handler = null;
  }

  /// Returns true if the session was opened in Tocar.
  static Future<bool> open(BuildContext context, Session session) async {
    final handler = _handler;
    if (handler == null) return false;
    Navigator.of(context).popUntil((route) => route.isFirst);
    return handler(session);
  }
}
