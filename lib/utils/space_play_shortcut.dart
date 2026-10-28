import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Adds a global Space → play/stop shortcut to a screen's [State].
///
/// The shortcut is ignored while:
/// * a text field has focus (Space must type a space),
/// * [spaceShortcutBlocked] is true (screen-specific editing states),
/// * another route (dialog, sheet, pushed screen) is on top of this one,
/// * a modifier key (Ctrl/Alt/Shift/Meta) is held.
///
/// The handler runs before the focus tree, so when it fires it also prevents
/// Space from activating whatever button has focus (no double toggles).
mixin SpacePlayShortcut<T extends StatefulWidget> on State<T> {
  /// Called on Space press when the shortcut applies.
  void onSpacePlayToggle();

  /// Override to suspend the shortcut (e.g. while a custom editor is open).
  bool get spaceShortcutBlocked => false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleSpaceKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleSpaceKey);
    super.dispose();
  }

  bool _handleSpaceKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.space) return false;
    if (event is KeyUpEvent) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (spaceShortcutBlocked || _isTextFieldFocused()) return false;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed || keyboard.isShiftPressed) {
      return false;
    }

    // Consume auto-repeat too, but only toggle on the initial press.
    if (event is KeyDownEvent) onSpacePlayToggle();
    return true;
  }

  static bool _isTextFieldFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
