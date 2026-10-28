import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/utils/structure_input.dart';

/// On-screen keypad for editing a pattern structure (`3+2`, `2:3/4`...).
///
/// It edits [controller] directly, respecting caret and selection, and runs
/// every insertion through [StructureInput] so it accepts exactly the same
/// input as the physical keyboard. Keys that would produce an invalid value
/// are shown disabled, so the keypad also documents the syntax.
///
/// * [PatternKeypadStyle.docked]: full-width bar at the bottom (mobile).
/// * [PatternKeypadStyle.popover]: compact card anchored to the field (desktop).
enum PatternKeypadStyle { docked, popover }

class PatternKeypad extends StatelessWidget {
  const PatternKeypad({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.style = PatternKeypadStyle.docked,
    this.display,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final PatternKeypadStyle style;

  /// Optional row shown above the keys (docked style): the text field being
  /// edited, so it's big and readable on phones.
  final Widget? display;

  /// Width of the popover variant.
  static const double popoverWidth = 232;

  /// Max width of the keys area in the docked variant (tablets / wide phones).
  static const double dockedMaxWidth = 480;

  bool get _isPopover => style == PatternKeypadStyle.popover;

  @override
  Widget build(BuildContext context) {
    final keys = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _buildKeys(context),
      ),
    );

    // Swallow taps on the keypad background so they don't reach the
    // "tap outside to close" detector behind it.
    final Widget body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: keys,
    );

    if (_isPopover) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          width: popoverWidth,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceHighlight(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary(context), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: body,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight(context),
        border: Border(top: BorderSide(color: AppColors.primary(context), width: 2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: dockedMaxWidth),
          child: display == null
              ? body
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text display row showing what's being typed
                    Container(
                      margin: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background(context),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary(context).withOpacity(0.5)),
                      ),
                      child: display,
                    ),
                    body,
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildKeys(BuildContext context) {
    final green = AppColors.accentGreen(context);
    final double keyHeight = _isPopover ? 38 : 40;

    Widget row(List<Widget> children) => Row(children: children);
    Widget char(String c, {Color? color}) => Expanded(
          child: _KeypadButton(
            label: c,
            height: keyHeight,
            color: color,
            enabled: StructureInput.insert(controller.value, c) != null,
            onTap: () => _insert(c),
          ),
        );

    final bool canSubmit = StructureInput.isComplete(controller.text);
    final bool canDelete = StructureInput.backspace(controller.value) != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([char('1'), char('2'), char('3'), char('+', color: green)]),
        row([char('4'), char('5'), char('6'), char('/', color: green)]),
        row([char('7'), char('8'), char('9'), char(':', color: green)]),
        row([
          char('0'),
          Expanded(
            child: _KeypadButton(
              icon: Icons.backspace_outlined,
              height: keyHeight,
              color: AppColors.accentRed(context),
              enabled: canDelete,
              onTap: _backspace,
            ),
          ),
          Expanded(
            flex: 2,
            child: _KeypadButton(
              label: 'OK',
              height: keyHeight,
              color: AppColors.primary(context),
              enabled: canSubmit,
              onTap: onSubmit,
            ),
          ),
        ]),
        if (_isPopover)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              'Enter confirma · Esc cancela · Tab siguiente',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context)),
            ),
          ),
      ],
    );
  }

  void _insert(String chars) {
    final next = StructureInput.insert(controller.value, chars);
    if (next != null) controller.value = next;
  }

  void _backspace() {
    final next = StructureInput.backspace(controller.value);
    if (next != null) controller.value = next;
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    this.label,
    this.icon,
    required this.height,
    required this.enabled,
    required this.onTap,
    this.color,
  });

  final String? label;
  final IconData? icon;
  final double height;
  final bool enabled;
  final VoidCallback onTap;

  /// Accent color for control keys; null for plain digit keys.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool isControl = color != null;
    final Color fg = isControl ? color! : AppColors.textPrimary(context);
    final Color bg = isControl ? color!.withOpacity(0.2) : AppColors.surface(context);
    final Color borderColor = isControl ? color! : AppColors.border(context);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Disabled keys still swallow the tap so it doesn't close the editor.
        onTap: enabled ? onTap : () {},
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1.0 : 0.3,
          child: Container(
            margin: const EdgeInsets.all(2),
            height: height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, color: fg, size: 18)
                : Text(
                    label!,
                    style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
