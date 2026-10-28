import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/utils/structure_input.dart';

TextEditingValue _v(String text, [int? caret]) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret ?? text.length));

void main() {
  group('isComplete', () {
    test('accepts valid structures', () {
      for (final s in ['3', '3+2', '2/3', '3:2', '3:2/4', '12+32/12', '5:64']) {
        expect(StructureInput.isComplete(s), isTrue, reason: s);
      }
    });
    test('rejects incomplete or invalid structures', () {
      for (final s in ['', '3+', '3:', '3/', '3:/4', '+3', '3++2', '0', '33', '3/13', '3:65', '03']) {
        expect(StructureInput.isComplete(s), isFalse, reason: s);
      }
    });
  });

  group('isPartial', () {
    test('accepts prefixes of valid structures', () {
      for (final s in ['', '3', '3+', '3:', '3/', '3:2/', '1']) {
        expect(StructureInput.isPartial(s), isTrue, reason: s);
      }
    });
    test('rejects sequences that can never be valid', () {
      for (final s in ['+', '3++', '3:/', '3//', '3::', '3/2:', '0', '33', '3/13', '123']) {
        expect(StructureInput.isPartial(s), isFalse, reason: s);
      }
    });
  });

  group('insert', () {
    test('inserts at caret and replaces selection', () {
      expect(StructureInput.insert(_v('32', 1), '+')!.text, '3+2');
      final selected = const TextEditingValue(text: '3+2', selection: TextSelection(baseOffset: 0, extentOffset: 3));
      expect(StructureInput.insert(selected, '5')!.text, '5');
    });
    test('rejects invalid characters and sequences', () {
      expect(StructureInput.insert(_v('3+'), '+'), isNull);
      expect(StructureInput.insert(_v(''), '/'), isNull);
      expect(StructureInput.insert(_v('12'), '3'), isNull);
      expect(StructureInput.insert(_v('3'), 'a'), isNull);
    });
  });

  test('filterEdit strips spaces on paste and always allows deletions', () {
    expect(StructureInput.filterEdit(_v(''), _v('3 + 2')).text, '3+2');
    expect(StructureInput.filterEdit(_v('3+2'), _v('+2', 0)).text, '+2');
  });

  test('backspace deletes before caret or the selection', () {
    expect(StructureInput.backspace(_v('3+2'))!.text, '3+');
    expect(StructureInput.backspace(_v('3+2', 0)), isNull);
  });
}
