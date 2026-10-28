import 'package:flutter/services.dart';

/// Validation and editing helpers for pattern structure strings.
///
/// Grammar (spaces are ignored):
///   structure := segment ('+' segment)*
///   segment   := count (':' ratio)? ('/' subdivision)?
///
/// Limits mirror the parser in `MetronomeProvider`:
///   count 1-32, ratio 1-64, subdivision 1-12, no leading zeros.
class StructureInput {
  StructureInput._();

  /// Characters that can ever appear in a structure.
  static const String allowedChars = '0123456789+/:';

  static const int maxCount = 32;
  static const int maxRatio = 64;
  static const int maxSubdivision = 12;

  static final RegExp _disallowed = RegExp(r'[^0-9+/:]');
  static final RegExp _segment = RegExp(r'^(\d{1,2})(:(\d{0,2}))?(/(\d{0,2}))?$');

  /// True if [text] is a complete, committable structure (e.g. `3+2`, `3:2/4`).
  static bool isComplete(String text) => _check(text, complete: true);

  /// True if [text] is complete or can still become complete by typing more
  /// characters at the end (e.g. `3+`, `3:`, `2/`).
  static bool isPartial(String text) => _check(text, complete: false);

  static bool _check(String text, {required bool complete}) {
    if (text.isEmpty) return !complete;
    final segments = text.split('+');
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isLast = i == segments.length - 1;
      if (seg.isEmpty) {
        // Only a trailing '+' is acceptable while typing.
        if (complete || !isLast || i == 0) return false;
        continue;
      }
      if (!_segmentOk(seg, complete: complete)) return false;
    }
    return true;
  }

  static bool _segmentOk(String seg, {required bool complete}) {
    final m = _segment.firstMatch(seg);
    if (m == null) return false;
    if (!_numberOk(m.group(1)!, maxCount)) return false;

    final bool hasRatio = m.group(2) != null;
    final bool hasSub = m.group(4) != null;

    if (hasRatio) {
      final ratio = m.group(3)!;
      if (ratio.isEmpty) {
        // "3:" is fine while typing, "3:/4" never is.
        if (complete || hasSub) return false;
      } else if (!_numberOk(ratio, maxRatio)) {
        return false;
      }
    }
    if (hasSub) {
      final sub = m.group(5)!;
      if (sub.isEmpty) {
        if (complete) return false;
      } else if (!_numberOk(sub, maxSubdivision)) {
        return false;
      }
    }
    return true;
  }

  static bool _numberOk(String digits, int max) {
    if (digits.startsWith('0')) return false;
    return int.parse(digits) <= max;
  }

  /// Applies an edit coming from either the physical keyboard or the keypad.
  /// Returns [oldValue] unchanged if the edit would produce an invalid value.
  static TextEditingValue filterEdit(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text == oldValue.text) return newValue;

    // Strip disallowed characters (spaces, letters...) keeping the caret coherent.
    TextEditingValue value = newValue;
    if (_disallowed.hasMatch(newValue.text)) {
      final int caret = newValue.selection.extentOffset.clamp(0, newValue.text.length);
      final String before = newValue.text.substring(0, caret).replaceAll(_disallowed, '');
      final String after = newValue.text.substring(caret).replaceAll(_disallowed, '');
      value = TextEditingValue(
        text: before + after,
        selection: TextSelection.collapsed(offset: before.length),
      );
      if (value.text == oldValue.text) return oldValue;
    }

    // Deletions are always allowed so the user can fix any state.
    if (value.text.length < oldValue.text.length) return value;

    return isPartial(value.text) ? value : oldValue;
  }

  /// Result of inserting [chars] at the current selection, or null if rejected.
  static TextEditingValue? insert(TextEditingValue current, String chars) {
    final sel = current.selection;
    final text = current.text;
    final int start = sel.isValid ? sel.start : text.length;
    final int end = sel.isValid ? sel.end : text.length;
    final candidate = TextEditingValue(
      text: text.substring(0, start) + chars + text.substring(end),
      selection: TextSelection.collapsed(offset: start + chars.length),
    );
    final result = filterEdit(current, candidate);
    return identical(result, current) ? null : result;
  }

  /// Result of a backspace at the current selection, or null if nothing to delete.
  static TextEditingValue? backspace(TextEditingValue current) {
    final sel = current.selection;
    final text = current.text;
    if (text.isEmpty) return null;
    int start = sel.isValid ? sel.start : text.length;
    final int end = sel.isValid ? sel.end : text.length;
    if (start == end) {
      if (start == 0) return null;
      start -= 1;
    }
    return TextEditingValue(
      text: text.substring(0, start) + text.substring(end),
      selection: TextSelection.collapsed(offset: start),
    );
  }
}

/// [TextInputFormatter] that blocks any character or sequence that cannot
/// form a valid structure.
class StructureInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return StructureInput.filterEdit(oldValue, newValue);
  }
}
