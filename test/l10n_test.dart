import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against missing translations: every locale must define exactly the
/// same message keys and the same placeholders as the Spanish template.
void main() {
  Map<String, dynamic> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  Set<String> placeholders(String message) =>
      RegExp(r'\{(\w+)[,}]').allMatches(message).map((m) => m.group(1)!).toSet();

  final template = load('es');

  for (final locale in ['en']) {
    group('app_$locale.arb', () {
      final arb = load(locale);

      test('has the same keys as the Spanish template', () {
        final missing = messageKeys(template).difference(messageKeys(arb));
        final extra = messageKeys(arb).difference(messageKeys(template));
        expect(missing, isEmpty, reason: 'Missing in $locale');
        expect(extra, isEmpty, reason: 'Not in template');
      });

      test('uses the same placeholders', () {
        for (final key in messageKeys(template)) {
          final translated = arb[key];
          if (translated is! String) continue;
          expect(
            placeholders(translated),
            containsAll(placeholders(template[key] as String)
                .where((p) => (template['@$key']?['placeholders'] as Map?)?.containsKey(p) ?? false)),
            reason: 'Placeholder mismatch in "$key"',
          );
        }
      });
    });
  }
}
