import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Locales the app ships translations for. English goes first so it is the
/// fallback when the device language is not supported.
const List<Locale> kSupportedLocales = [Locale('en'), Locale('es')];

/// Shorthand: `context.l10n.someKey`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Access to the active translations from code without a [BuildContext]
/// (providers, services, models). Updated by the root `MaterialApp` builder.
///
/// Prefer `context.l10n` inside widgets.
class L10n {
  L10n._();

  static AppLocalizations _current = lookupAppLocalizations(const Locale('en'));
  static AppLocalizations get current => _current;
  static set current(AppLocalizations value) => _current = value;
}

/// Picks the best supported locale for the device: Spanish for any `es_*`,
/// English otherwise.
Locale resolveAppLocale(List<Locale>? deviceLocales) {
  for (final locale in deviceLocales ?? const <Locale>[]) {
    for (final supported in kSupportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
  }
  return kSupportedLocales.first;
}

/// Display name for a sound set id (see `ClickSynth.soundSets`).
///
/// The ids themselves stay in Spanish because they are persisted in prefs,
/// sessions and shared links; only the label shown to the user is translated.
String soundSetLabel(AppLocalizations l10n, String id) {
  switch (id) {
    case 'Clásico':
      return l10n.soundSetClasico;
    case 'Madera':
      return l10n.soundSetMadera;
    case 'Claves':
      return l10n.soundSetClaves;
    case 'Beep':
      return l10n.soundSetBeep;
    case 'Hi-hat':
      return l10n.soundSetHihat;
    case 'Bombo':
      return l10n.soundSetBombo;
    case 'Redoblante':
      return l10n.soundSetRedoblante;
  }
  return id;
}
