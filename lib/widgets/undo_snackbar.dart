import 'package:flutter/material.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';

/// Confirmation dialog for destructive actions. Returns true if confirmed.
/// [confirmLabel] defaults to the localized "DELETE".
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      final l10n = ctx.l10n;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel.toUpperCase(), style: TextStyle(color: colors.onSurface.withOpacity(0.7))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? l10n.commonDelete.toUpperCase(), style: TextStyle(color: colors.secondary, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
  return ok == true;
}

/// Shows a "«item» eliminado · DESHACER" snackbar on the nearest
/// [ScaffoldMessenger]. Replaces any snackbar currently visible.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      // Since Flutter 3.38 snackbars with an action persist by default.
      persist: false,
      action: SnackBarAction(label: context.l10n.commonUndo.toUpperCase(), onPressed: onUndo),
    ),
  );
}

/// Inline "deleted · DESHACER" strip, for places where a snackbar would be
/// hidden (e.g. inside a modal bottom sheet, which covers the Scaffold).
class UndoStrip extends StatelessWidget {
  final String message;
  final VoidCallback onUndo;

  const UndoStrip({super.key, required this.message, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snack = theme.snackBarTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: snack.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: snack.contentTextStyle, maxLines: 2, overflow: TextOverflow.ellipsis)),
          TextButton(
            onPressed: onUndo,
            child: Text(context.l10n.commonUndo.toUpperCase(), style: TextStyle(color: snack.actionTextColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
