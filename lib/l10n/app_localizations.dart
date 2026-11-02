import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Metrónomo'**
  String get appTitle;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Idioma del sistema'**
  String get languageSystem;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @soundSetClasico.
  ///
  /// In es, this message translates to:
  /// **'Clásico'**
  String get soundSetClasico;

  /// No description provided for @soundSetMadera.
  ///
  /// In es, this message translates to:
  /// **'Madera'**
  String get soundSetMadera;

  /// No description provided for @soundSetClaves.
  ///
  /// In es, this message translates to:
  /// **'Claves'**
  String get soundSetClaves;

  /// No description provided for @soundSetBeep.
  ///
  /// In es, this message translates to:
  /// **'Beep'**
  String get soundSetBeep;

  /// No description provided for @soundSetHihat.
  ///
  /// In es, this message translates to:
  /// **'Hi-hat'**
  String get soundSetHihat;

  /// No description provided for @soundSetBombo.
  ///
  /// In es, this message translates to:
  /// **'Bombo'**
  String get soundSetBombo;

  /// No description provided for @soundSetRedoblante.
  ///
  /// In es, this message translates to:
  /// **'Redoblante'**
  String get soundSetRedoblante;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @commonOk.
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get commonAccept;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @commonRename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get commonRename;

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @commonEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get commonEdit;

  /// No description provided for @commonCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get commonCreate;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @commonShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get commonShare;

  /// No description provided for @commonUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get commonUndo;

  /// No description provided for @commonName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get commonName;

  /// No description provided for @homeTabPlay.
  ///
  /// In es, this message translates to:
  /// **'Tocar'**
  String get homeTabPlay;

  /// No description provided for @homeTabLibrary.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca'**
  String get homeTabLibrary;

  /// No description provided for @homeTabSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get homeTabSettings;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Actualización Necesaria'**
  String get updateRequiredTitle;

  /// No description provided for @updateDefaultMessage.
  ///
  /// In es, this message translates to:
  /// **'Hay una nueva versión disponible.\nActualizá para seguir usando Metrónomo.'**
  String get updateDefaultMessage;

  /// No description provided for @updateDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando actualización…'**
  String get updateDownloading;

  /// No description provided for @updateButton.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get updateButton;

  /// No description provided for @shareNativeFailedCopied.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el menú de compartir. Copiamos el link.'**
  String get shareNativeFailedCopied;

  /// No description provided for @shareGeneratingLink.
  ///
  /// In es, this message translates to:
  /// **'Generando link…'**
  String get shareGeneratingLink;

  /// No description provided for @shareLinkCreateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el link.'**
  String get shareLinkCreateFailed;

  /// No description provided for @shareShareVia.
  ///
  /// In es, this message translates to:
  /// **'COMPARTIR EN…'**
  String get shareShareVia;

  /// No description provided for @shareLinkCopied.
  ///
  /// In es, this message translates to:
  /// **'¡LINK COPIADO!'**
  String get shareLinkCopied;

  /// No description provided for @shareCopyLink.
  ///
  /// In es, this message translates to:
  /// **'COPIAR LINK'**
  String get shareCopyLink;

  /// No description provided for @shareHeadingPattern.
  ///
  /// In es, this message translates to:
  /// **'Compartir patrón'**
  String get shareHeadingPattern;

  /// No description provided for @shareHeadingSession.
  ///
  /// In es, this message translates to:
  /// **'Compartir sesión'**
  String get shareHeadingSession;

  /// No description provided for @shareHeadingPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Compartir playlist'**
  String get shareHeadingPlaylist;

  /// No description provided for @shareSubtitlePattern.
  ///
  /// In es, this message translates to:
  /// **'«{name}» · {structure}'**
  String shareSubtitlePattern(String name, String structure);

  /// No description provided for @shareSubtitleSession.
  ///
  /// In es, this message translates to:
  /// **'«{name}» · {bpm} BPM · {count, plural, =1{1 patrón} other{{count} patrones}}'**
  String shareSubtitleSession(String name, int bpm, int count);

  /// No description provided for @shareSubtitlePlaylist.
  ///
  /// In es, this message translates to:
  /// **'«{name}» · {count, plural, =1{1 sesión} other{{count} sesiones}}'**
  String shareSubtitlePlaylist(String name, int count);

  /// No description provided for @shareErrorConnect.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor para crear el link.'**
  String get shareErrorConnect;

  /// No description provided for @shareErrorPermission.
  ///
  /// In es, this message translates to:
  /// **'El servidor rechazó el link (permisos).'**
  String get shareErrorPermission;

  /// No description provided for @shareErrorNetwork.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el link. Revisá tu conexión.'**
  String get shareErrorNetwork;

  /// No description provided for @shareTitlePattern.
  ///
  /// In es, this message translates to:
  /// **'Patrón: {name}'**
  String shareTitlePattern(String name);

  /// No description provided for @shareTitleSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión: {name}'**
  String shareTitleSession(String name);

  /// No description provided for @shareTitlePlaylist.
  ///
  /// In es, this message translates to:
  /// **'Playlist: {name}'**
  String shareTitlePlaylist(String name);

  /// No description provided for @shareMessagePattern.
  ///
  /// In es, this message translates to:
  /// **'🎵 Te comparto el patrón «{name}» ({structure}) en Metrónomo:'**
  String shareMessagePattern(String name, String structure);

  /// No description provided for @shareMessageSession.
  ///
  /// In es, this message translates to:
  /// **'🎵 Te comparto la sesión «{name}» ({bpm} BPM · {count, plural, =1{1 patrón} other{{count} patrones}}) en Metrónomo:'**
  String shareMessageSession(String name, int bpm, int count);

  /// No description provided for @shareMessagePlaylist.
  ///
  /// In es, this message translates to:
  /// **'🎵 Te comparto la playlist «{name}» ({count, plural, =1{1 sesión} other{{count} sesiones}}) en Metrónomo:'**
  String shareMessagePlaylist(String name, int count);

  /// No description provided for @patternDefaultName.
  ///
  /// In es, this message translates to:
  /// **'Patrón'**
  String get patternDefaultName;

  /// No description provided for @patternNumbered.
  ///
  /// In es, this message translates to:
  /// **'Patrón {number}'**
  String patternNumbered(int number);

  /// No description provided for @patternCopyName.
  ///
  /// In es, this message translates to:
  /// **'{name} (copia)'**
  String patternCopyName(String name);

  /// No description provided for @sessionDefaultDescription.
  ///
  /// In es, this message translates to:
  /// **'Sesión por defecto con birritmia de 3/4 y 6/8'**
  String get sessionDefaultDescription;

  /// No description provided for @metronomePatternAddedToSession.
  ///
  /// In es, this message translates to:
  /// **'«{name}» agregado a la sesión'**
  String metronomePatternAddedToSession(String name);

  /// No description provided for @metronomeOpeningSharedLink.
  ///
  /// In es, this message translates to:
  /// **'Abriendo link compartido...'**
  String get metronomeOpeningSharedLink;

  /// No description provided for @metronomeShareInvalid.
  ///
  /// In es, this message translates to:
  /// **'El enlace compartido no es válido o ha expirado.'**
  String get metronomeShareInvalid;

  /// No description provided for @metronomeShareImportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar el contenido compartido.'**
  String get metronomeShareImportFailed;

  /// No description provided for @metronomeReceivedPattern.
  ///
  /// In es, this message translates to:
  /// **'Patrón recibido'**
  String get metronomeReceivedPattern;

  /// No description provided for @metronomeReceivedSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión recibida'**
  String get metronomeReceivedSession;

  /// No description provided for @metronomeReceivedPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Playlist recibida'**
  String get metronomeReceivedPlaylist;

  /// No description provided for @metronomeImportAlreadyInLibrary.
  ///
  /// In es, this message translates to:
  /// **'Ya estaba en tu biblioteca.'**
  String get metronomeImportAlreadyInLibrary;

  /// No description provided for @metronomeImportAddedPattern.
  ///
  /// In es, this message translates to:
  /// **'Se agregó a tu biblioteca.'**
  String get metronomeImportAddedPattern;

  /// No description provided for @metronomeImportAddedSession.
  ///
  /// In es, this message translates to:
  /// **'Se agregó a tu biblioteca ({patternCount, plural, =1{1 patrón} other{{patternCount} patrones}}).'**
  String metronomeImportAddedSession(int patternCount);

  /// No description provided for @metronomeImportAddedPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Se agregó a tu biblioteca ({sessionCount, plural, =1{1 sesión} other{{sessionCount} sesiones}}, {patternCount, plural, =1{1 patrón} other{{patternCount} patrones}}).'**
  String metronomeImportAddedPlaylist(int sessionCount, int patternCount);

  /// No description provided for @metronomeImportOpenPrompt.
  ///
  /// In es, this message translates to:
  /// **'«{name}»\n{status}\n\n¿Querés abrirlo ahora?'**
  String metronomeImportOpenPrompt(String name, String status);

  /// No description provided for @metronomeImportSaveOnly.
  ///
  /// In es, this message translates to:
  /// **'SOLO GUARDAR'**
  String get metronomeImportSaveOnly;

  /// No description provided for @metronomeImportOpen.
  ///
  /// In es, this message translates to:
  /// **'ABRIR'**
  String get metronomeImportOpen;

  /// No description provided for @metronomeUntitled.
  ///
  /// In es, this message translates to:
  /// **'Sin Título'**
  String get metronomeUntitled;

  /// No description provided for @metronomeUnsavedTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambios sin guardar'**
  String get metronomeUnsavedTitle;

  /// No description provided for @metronomeUnsavedMessage.
  ///
  /// In es, this message translates to:
  /// **'La sesión «{name}» tiene cambios sin guardar. ¿Qué querés hacer antes de continuar?'**
  String metronomeUnsavedMessage(String name);

  /// No description provided for @metronomeDiscard.
  ///
  /// In es, this message translates to:
  /// **'DESCARTAR'**
  String get metronomeDiscard;

  /// No description provided for @metronomeDefaultSessionName.
  ///
  /// In es, this message translates to:
  /// **'Sesión'**
  String get metronomeDefaultSessionName;

  /// No description provided for @metronomeNewSessionSnack.
  ///
  /// In es, this message translates to:
  /// **'Sesión nueva'**
  String get metronomeNewSessionSnack;

  /// No description provided for @metronomePatternRemoved.
  ///
  /// In es, this message translates to:
  /// **'«{name}» quitado de la sesión'**
  String metronomePatternRemoved(String name);

  /// No description provided for @metronomeSessionSaved.
  ///
  /// In es, this message translates to:
  /// **'«{name}» guardada'**
  String metronomeSessionSaved(String name);

  /// No description provided for @metronomeSaveSessionTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar Sesión'**
  String get metronomeSaveSessionTitle;

  /// No description provided for @metronomeSessionNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la Sesión'**
  String get metronomeSessionNameLabel;

  /// No description provided for @metronomeDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get metronomeDescriptionLabel;

  /// No description provided for @metronomeLoadSessionTitle.
  ///
  /// In es, this message translates to:
  /// **'Cargar Sesión'**
  String get metronomeLoadSessionTitle;

  /// No description provided for @metronomeSessionDeleted.
  ///
  /// In es, this message translates to:
  /// **'«{name}» eliminada'**
  String metronomeSessionDeleted(String name);

  /// No description provided for @metronomeNoSessions.
  ///
  /// In es, this message translates to:
  /// **'No hay sesiones guardadas.'**
  String get metronomeNoSessions;

  /// No description provided for @metronomeSessionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{bpm} BPM • {count, plural, =1{1 pista} other{{count} pistas}}'**
  String metronomeSessionSubtitle(int bpm, int count);

  /// No description provided for @metronomeShareSession.
  ///
  /// In es, this message translates to:
  /// **'Compartir sesión'**
  String get metronomeShareSession;

  /// No description provided for @metronomeDeleteSession.
  ///
  /// In es, this message translates to:
  /// **'Eliminar sesión'**
  String get metronomeDeleteSession;

  /// No description provided for @metronomeDeleteSessionConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{name}» de tu biblioteca?'**
  String metronomeDeleteSessionConfirm(String name);

  /// No description provided for @metronomeLoadPatternTitle.
  ///
  /// In es, this message translates to:
  /// **'Cargar Patrón'**
  String get metronomeLoadPatternTitle;

  /// No description provided for @metronomePatternDeletedFromLibrary.
  ///
  /// In es, this message translates to:
  /// **'«{name}» eliminado de la librería'**
  String metronomePatternDeletedFromLibrary(String name);

  /// No description provided for @metronomeNoPatterns.
  ///
  /// In es, this message translates to:
  /// **'No hay patrones en la librería.'**
  String get metronomeNoPatterns;

  /// No description provided for @metronomeStructureLabel.
  ///
  /// In es, this message translates to:
  /// **'Estructura: {structure}'**
  String metronomeStructureLabel(String structure);

  /// No description provided for @metronomeSharePattern.
  ///
  /// In es, this message translates to:
  /// **'Compartir patrón'**
  String get metronomeSharePattern;

  /// No description provided for @metronomeDeletePatternFromLibrary.
  ///
  /// In es, this message translates to:
  /// **'Eliminar patrón de la librería'**
  String get metronomeDeletePatternFromLibrary;

  /// No description provided for @metronomeTitle.
  ///
  /// In es, this message translates to:
  /// **'METRÓNOMO'**
  String get metronomeTitle;

  /// No description provided for @metronomeSaveSessionTooltip.
  ///
  /// In es, this message translates to:
  /// **'Guardar sesión'**
  String get metronomeSaveSessionTooltip;

  /// No description provided for @metronomeMoreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get metronomeMoreOptions;

  /// No description provided for @metronomeMenuNewSession.
  ///
  /// In es, this message translates to:
  /// **'Nueva sesión'**
  String get metronomeMenuNewSession;

  /// No description provided for @metronomeMenuOpenSession.
  ///
  /// In es, this message translates to:
  /// **'Abrir sesión…'**
  String get metronomeMenuOpenSession;

  /// No description provided for @metronomeMenuSaveAs.
  ///
  /// In es, this message translates to:
  /// **'Guardar como…'**
  String get metronomeMenuSaveAs;

  /// No description provided for @metronomeMenuPlaylists.
  ///
  /// In es, this message translates to:
  /// **'Playlists'**
  String get metronomeMenuPlaylists;

  /// No description provided for @metronomeMenuSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get metronomeMenuSettings;

  /// No description provided for @metronomeDefaultPatternName.
  ///
  /// In es, this message translates to:
  /// **'Patrón {number}'**
  String metronomeDefaultPatternName(int number);

  /// No description provided for @metronomeAdd.
  ///
  /// In es, this message translates to:
  /// **'AÑADIR'**
  String get metronomeAdd;

  /// No description provided for @metronomeLibrary.
  ///
  /// In es, this message translates to:
  /// **'LIBRERÍA'**
  String get metronomeLibrary;

  /// No description provided for @metronomeTapToRename.
  ///
  /// In es, this message translates to:
  /// **'Tocá para renombrar'**
  String get metronomeTapToRename;

  /// No description provided for @metronomePatternOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones del patrón'**
  String get metronomePatternOptions;

  /// No description provided for @metronomeSaveToLibrary.
  ///
  /// In es, this message translates to:
  /// **'Guardar en la librería'**
  String get metronomeSaveToLibrary;

  /// No description provided for @metronomeDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Duplicar'**
  String get metronomeDuplicate;

  /// No description provided for @metronomeRemoveFromSession.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la sesión'**
  String get metronomeRemoveFromSession;

  /// No description provided for @metronomeRenamePatternTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar patrón'**
  String get metronomeRenamePatternTitle;

  /// No description provided for @metronomePatternUpdatedInLibrary.
  ///
  /// In es, this message translates to:
  /// **'«{name}» actualizado en la librería'**
  String metronomePatternUpdatedInLibrary(String name);

  /// No description provided for @metronomePatternSavedToLibrary.
  ///
  /// In es, this message translates to:
  /// **'«{name}» guardado en la librería'**
  String metronomePatternSavedToLibrary(String name);

  /// No description provided for @metronomePatternSoundTooltip.
  ///
  /// In es, this message translates to:
  /// **'Sonido del patrón: {sound}'**
  String metronomePatternSoundTooltip(String sound);

  /// No description provided for @metronomeGlobalSoundTooltip.
  ///
  /// In es, this message translates to:
  /// **'Sonido: {sound} (global)'**
  String metronomeGlobalSoundTooltip(String sound);

  /// No description provided for @metronomeSoundGlobal.
  ///
  /// In es, this message translates to:
  /// **'Global ({sound})'**
  String metronomeSoundGlobal(String sound);

  /// No description provided for @metronomeStructureHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. 3+2'**
  String get metronomeStructureHint;

  /// No description provided for @transportTapToTypeTempo.
  ///
  /// In es, this message translates to:
  /// **'Tocá para escribir el tempo'**
  String get transportTapToTypeTempo;

  /// No description provided for @transportTempoSemantics.
  ///
  /// In es, this message translates to:
  /// **'Tempo {bpm} BPM. Tocá para escribirlo'**
  String transportTempoSemantics(int bpm);

  /// No description provided for @transportStepUp.
  ///
  /// In es, this message translates to:
  /// **'Subir {amount} BPM (mantené para repetir)'**
  String transportStepUp(int amount);

  /// No description provided for @transportStepDown.
  ///
  /// In es, this message translates to:
  /// **'Bajar {amount} BPM (mantené para repetir)'**
  String transportStepDown(int amount);

  /// No description provided for @transportTempoTitle.
  ///
  /// In es, this message translates to:
  /// **'Tempo'**
  String get transportTempoTitle;

  /// No description provided for @transportStop.
  ///
  /// In es, this message translates to:
  /// **'Detener'**
  String get transportStop;

  /// No description provided for @transportPlay.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get transportPlay;

  /// No description provided for @transportTapTempo.
  ///
  /// In es, this message translates to:
  /// **'Tap tempo'**
  String get transportTapTempo;

  /// No description provided for @transportTap.
  ///
  /// In es, this message translates to:
  /// **'TAP'**
  String get transportTap;

  /// No description provided for @macroCycleTitle.
  ///
  /// In es, this message translates to:
  /// **'CICLO MACRO'**
  String get macroCycleTitle;

  /// No description provided for @macroBeatsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 Pulso} other{{count} Pulsos}}'**
  String macroBeatsCount(int count);

  /// No description provided for @macroLegendAccent.
  ///
  /// In es, this message translates to:
  /// **'Acento'**
  String get macroLegendAccent;

  /// No description provided for @macroLegendNormal.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get macroLegendNormal;

  /// No description provided for @macroLegendSoft.
  ///
  /// In es, this message translates to:
  /// **'Suave'**
  String get macroLegendSoft;

  /// No description provided for @macroLegendSilence.
  ///
  /// In es, this message translates to:
  /// **'Silencio'**
  String get macroLegendSilence;

  /// No description provided for @macroEditHints.
  ///
  /// In es, this message translates to:
  /// **'· Tocá una celda para cambiarla · Mantené y arrastrá para el volumen'**
  String get macroEditHints;

  /// No description provided for @mixerVolumeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Volumen {percent}% (arrastrá)'**
  String mixerVolumeTooltip(int percent);

  /// No description provided for @mixerMute.
  ///
  /// In es, this message translates to:
  /// **'Silenciar'**
  String get mixerMute;

  /// No description provided for @mixerSolo.
  ///
  /// In es, this message translates to:
  /// **'Solo'**
  String get mixerSolo;

  /// No description provided for @keypadShortcutsHint.
  ///
  /// In es, this message translates to:
  /// **'Enter confirma · Esc cancela · Tab siguiente'**
  String get keypadShortcutsHint;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'AJUSTES'**
  String get settingsTitle;

  /// No description provided for @settingsPlaybackTitle.
  ///
  /// In es, this message translates to:
  /// **'Reproducción'**
  String get settingsPlaybackTitle;

  /// No description provided for @settingsBackgroundPlaybackTitle.
  ///
  /// In es, this message translates to:
  /// **'Reproducción en segundo plano'**
  String get settingsBackgroundPlaybackTitle;

  /// No description provided for @settingsBackgroundPlaybackSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El metrónomo sigue sonando al minimizar la app'**
  String get settingsBackgroundPlaybackSubtitle;

  /// No description provided for @settingsKeepScreenOnTitle.
  ///
  /// In es, this message translates to:
  /// **'Mantener pantalla encendida'**
  String get settingsKeepScreenOnTitle;

  /// No description provided for @settingsKeepScreenOnSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Evita que el dispositivo se bloquee automáticamente'**
  String get settingsKeepScreenOnSubtitle;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la interfaz'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsSoundSetTitle.
  ///
  /// In es, this message translates to:
  /// **'Set de Sonidos'**
  String get settingsSoundSetTitle;

  /// No description provided for @settingsRandomSilenceTitle.
  ///
  /// In es, this message translates to:
  /// **'Silencios al Azar'**
  String get settingsRandomSilenceTitle;

  /// No description provided for @settingsRandomSilenceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Porcentaje de beats que se silencian aleatoriamente'**
  String get settingsRandomSilenceSubtitle;

  /// No description provided for @settingsUiScaleTitle.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de la Interfaz'**
  String get settingsUiScaleTitle;

  /// No description provided for @settingsInstallTitle.
  ///
  /// In es, this message translates to:
  /// **'Instalar Aplicación'**
  String get settingsInstallTitle;

  /// No description provided for @settingsInstallSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Instalá el metrónomo en tu dispositivo'**
  String get settingsInstallSubtitle;

  /// No description provided for @settingsInstalledTitle.
  ///
  /// In es, this message translates to:
  /// **'App Instalada'**
  String get settingsInstalledTitle;

  /// No description provided for @settingsInstalledMessage.
  ///
  /// In es, this message translates to:
  /// **'Estás usando la versión instalada del Metrónomo.'**
  String get settingsInstalledMessage;

  /// No description provided for @settingsInstallPrompt.
  ///
  /// In es, this message translates to:
  /// **'Instalá el Metrónomo en tu dispositivo para acceso rápido y uso sin conexión.'**
  String get settingsInstallPrompt;

  /// No description provided for @settingsInstallButton.
  ///
  /// In es, this message translates to:
  /// **'Instalar'**
  String get settingsInstallButton;

  /// No description provided for @settingsInstallManualIntro.
  ///
  /// In es, this message translates to:
  /// **'Podés instalar esta app desde el menú de tu navegador:'**
  String get settingsInstallManualIntro;

  /// No description provided for @settingsInstallStepChromeAndroid.
  ///
  /// In es, this message translates to:
  /// **'Menú ⋮ → \"Instalar aplicación\" o \"Añadir a pantalla de inicio\"'**
  String get settingsInstallStepChromeAndroid;

  /// No description provided for @settingsInstallStepChromePc.
  ///
  /// In es, this message translates to:
  /// **'Icono de instalación en la barra de direcciones o Menú ⋮ → \"Instalar app\"'**
  String get settingsInstallStepChromePc;

  /// No description provided for @settingsInstallStepSafariIos.
  ///
  /// In es, this message translates to:
  /// **'Tocar el botón Compartir → \"Agregar a pantalla de inicio\"'**
  String get settingsInstallStepSafariIos;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutDevelopedBy.
  ///
  /// In es, this message translates to:
  /// **'Desarrollado por Federico Randazzo'**
  String get settingsAboutDevelopedBy;

  /// No description provided for @settingsAboutVisitWebsite.
  ///
  /// In es, this message translates to:
  /// **'Visitar Sitio Web'**
  String get settingsAboutVisitWebsite;

  /// No description provided for @settingsForumTitle.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get settingsForumTitle;

  /// No description provided for @settingsForumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Consultas, sugerencias y novedades en el foro'**
  String get settingsForumSubtitle;

  /// No description provided for @settingsForumButton.
  ///
  /// In es, this message translates to:
  /// **'Ir al Foro'**
  String get settingsForumButton;

  /// No description provided for @settingsMoreAppsTitle.
  ///
  /// In es, this message translates to:
  /// **'Más apps'**
  String get settingsMoreAppsTitle;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get settingsAccountTitle;

  /// Nombre de la copia que se guarda cuando el mismo ítem se editó distinto en dos dispositivos.
  ///
  /// In es, this message translates to:
  /// **'{name} (otro dispositivo)'**
  String syncConflictCopyName(String name);

  /// No description provided for @libraryTitle.
  ///
  /// In es, this message translates to:
  /// **'BIBLIOTECA'**
  String get libraryTitle;

  /// No description provided for @librarySearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre…'**
  String get librarySearchHint;

  /// No description provided for @librarySearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get librarySearch;

  /// No description provided for @libraryCloseSearch.
  ///
  /// In es, this message translates to:
  /// **'Cerrar búsqueda'**
  String get libraryCloseSearch;

  /// No description provided for @libraryTabSessions.
  ///
  /// In es, this message translates to:
  /// **'Sesiones'**
  String get libraryTabSessions;

  /// No description provided for @libraryTabPatterns.
  ///
  /// In es, this message translates to:
  /// **'Patrones'**
  String get libraryTabPatterns;

  /// No description provided for @libraryTabPlaylists.
  ///
  /// In es, this message translates to:
  /// **'Playlists'**
  String get libraryTabPlaylists;

  /// No description provided for @libraryNewSession.
  ///
  /// In es, this message translates to:
  /// **'Nueva sesión'**
  String get libraryNewSession;

  /// No description provided for @libraryNoSessions.
  ///
  /// In es, this message translates to:
  /// **'No hay sesiones guardadas'**
  String get libraryNoSessions;

  /// No description provided for @libraryNoSessionsMatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna sesión coincide con «{query}»'**
  String libraryNoSessionsMatch(String query);

  /// No description provided for @libraryNoSessionsHint.
  ///
  /// In es, this message translates to:
  /// **'Armá una sesión en Tocar y guardala con 💾'**
  String get libraryNoSessionsHint;

  /// No description provided for @librarySessionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{bpm} BPM · {count, plural, =1{1 patrón} other{{count} patrones}}'**
  String librarySessionSubtitle(int bpm, int count);

  /// No description provided for @libraryInPlayBadge.
  ///
  /// In es, this message translates to:
  /// **'En Tocar'**
  String get libraryInPlayBadge;

  /// No description provided for @libraryOpenInPlay.
  ///
  /// In es, this message translates to:
  /// **'Abrir en Tocar'**
  String get libraryOpenInPlay;

  /// No description provided for @libraryDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Duplicar'**
  String get libraryDuplicate;

  /// No description provided for @librarySessionCreated.
  ///
  /// In es, this message translates to:
  /// **'«{name}» creada'**
  String librarySessionCreated(String name);

  /// No description provided for @libraryRenameSession.
  ///
  /// In es, this message translates to:
  /// **'Renombrar sesión'**
  String get libraryRenameSession;

  /// No description provided for @libraryDeleteSession.
  ///
  /// In es, this message translates to:
  /// **'Eliminar sesión'**
  String get libraryDeleteSession;

  /// No description provided for @libraryDeleteSessionConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{name}» de tu biblioteca?'**
  String libraryDeleteSessionConfirm(String name);

  /// No description provided for @librarySessionDeleted.
  ///
  /// In es, this message translates to:
  /// **'«{name}» eliminada'**
  String librarySessionDeleted(String name);

  /// No description provided for @libraryNoPatterns.
  ///
  /// In es, this message translates to:
  /// **'La librería de patrones está vacía'**
  String get libraryNoPatterns;

  /// No description provided for @libraryNoPatternsMatch.
  ///
  /// In es, this message translates to:
  /// **'Ningún patrón coincide con «{query}»'**
  String libraryNoPatternsMatch(String query);

  /// No description provided for @libraryNoPatternsHint.
  ///
  /// In es, this message translates to:
  /// **'En Tocar, usá ⋮ → «Guardar en la librería» en un patrón'**
  String get libraryNoPatternsHint;

  /// No description provided for @libraryAddToSession.
  ///
  /// In es, this message translates to:
  /// **'Agregar a la sesión'**
  String get libraryAddToSession;

  /// No description provided for @libraryRemoveFromLibrary.
  ///
  /// In es, this message translates to:
  /// **'Eliminar de la librería'**
  String get libraryRemoveFromLibrary;

  /// No description provided for @libraryRenamePattern.
  ///
  /// In es, this message translates to:
  /// **'Renombrar patrón'**
  String get libraryRenamePattern;

  /// No description provided for @libraryPatternRemoved.
  ///
  /// In es, this message translates to:
  /// **'«{name}» eliminado de la librería'**
  String libraryPatternRemoved(String name);

  /// No description provided for @libraryOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get libraryOptions;

  /// No description provided for @playlistsTitle.
  ///
  /// In es, this message translates to:
  /// **'PLAYLISTS'**
  String get playlistsTitle;

  /// No description provided for @playlistsNewTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva Playlist'**
  String get playlistsNewTitle;

  /// No description provided for @playlistsEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar Playlist'**
  String get playlistsEditTitle;

  /// No description provided for @playlistsDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get playlistsDescriptionLabel;

  /// No description provided for @playlistsUpdateButton.
  ///
  /// In es, this message translates to:
  /// **'ACTUALIZAR'**
  String get playlistsUpdateButton;

  /// No description provided for @playlistsDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar playlist'**
  String get playlistsDeleteTitle;

  /// No description provided for @playlistsDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{name}»? Las sesiones que contiene no se borran.'**
  String playlistsDeleteConfirm(String name);

  /// No description provided for @playlistsDeleted.
  ///
  /// In es, this message translates to:
  /// **'«{name}» eliminada'**
  String playlistsDeleted(String name);

  /// No description provided for @playlistsNewButton.
  ///
  /// In es, this message translates to:
  /// **'Nueva playlist'**
  String get playlistsNewButton;

  /// No description provided for @playlistsNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna playlist coincide con la búsqueda'**
  String get playlistsNoMatch;

  /// No description provided for @playlistsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay playlists'**
  String get playlistsEmpty;

  /// No description provided for @playlistsEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Creá una playlist para organizar tus sesiones'**
  String get playlistsEmptyHint;

  /// No description provided for @playlistsCreateButton.
  ///
  /// In es, this message translates to:
  /// **'CREAR PLAYLIST'**
  String get playlistsCreateButton;

  /// No description provided for @playlistsSessionCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 sesión} other{{count} sesiones}}'**
  String playlistsSessionCount(int count);

  /// No description provided for @playlistsOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones de la playlist'**
  String get playlistsOptions;

  /// No description provided for @playlistsDeletedSessionChip.
  ///
  /// In es, this message translates to:
  /// **'(eliminada)'**
  String get playlistsDeletedSessionChip;

  /// No description provided for @playlistsMoreCount.
  ///
  /// In es, this message translates to:
  /// **'+{count} más'**
  String playlistsMoreCount(int count);

  /// No description provided for @playlistsAddSession.
  ///
  /// In es, this message translates to:
  /// **'Agregar Sesión'**
  String get playlistsAddSession;

  /// No description provided for @playlistsAddSessionEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay sesiones guardadas.\nCreá sesiones desde el metrónomo.'**
  String get playlistsAddSessionEmpty;

  /// No description provided for @playlistsSessionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{bpm} BPM • {count} pistas'**
  String playlistsSessionSubtitle(int bpm, int count);

  /// No description provided for @playlistsNotFoundTitle.
  ///
  /// In es, this message translates to:
  /// **'Playlist no encontrada'**
  String get playlistsNotFoundTitle;

  /// No description provided for @playlistsNotFoundMessage.
  ///
  /// In es, this message translates to:
  /// **'Esta playlist fue eliminada.'**
  String get playlistsNotFoundMessage;

  /// No description provided for @playlistsPlay.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get playlistsPlay;

  /// No description provided for @playlistsDetailEmpty.
  ///
  /// In es, this message translates to:
  /// **'Playlist vacía'**
  String get playlistsDetailEmpty;

  /// No description provided for @playlistsDetailEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Agregá sesiones usando el botón +'**
  String get playlistsDetailEmptyHint;

  /// No description provided for @playlistsAddSessionButton.
  ///
  /// In es, this message translates to:
  /// **'AGREGAR SESIÓN'**
  String get playlistsAddSessionButton;

  /// No description provided for @playlistsDeletedSession.
  ///
  /// In es, this message translates to:
  /// **'(sesión eliminada)'**
  String get playlistsDeletedSession;

  /// No description provided for @playlistsRemoveSession.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la playlist'**
  String get playlistsRemoveSession;

  /// No description provided for @playlistsRemoved.
  ///
  /// In es, this message translates to:
  /// **'Quitada de la playlist'**
  String get playlistsRemoved;

  /// No description provided for @playlistsSessionRemoved.
  ///
  /// In es, this message translates to:
  /// **'«{name}» quitada de la playlist'**
  String playlistsSessionRemoved(String name);

  /// No description provided for @playlistItemEditSession.
  ///
  /// In es, this message translates to:
  /// **'Editar sesión'**
  String get playlistItemEditSession;

  /// No description provided for @playlistItemNotInLibrary.
  ///
  /// In es, this message translates to:
  /// **'No está en la biblioteca'**
  String get playlistItemNotInLibrary;

  /// No description provided for @playlistItemRestoreToLibrary.
  ///
  /// In es, this message translates to:
  /// **'Restaurar en la biblioteca'**
  String get playlistItemRestoreToLibrary;

  /// No description provided for @playlistItemRestoreTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión fuera de la biblioteca'**
  String get playlistItemRestoreTitle;

  /// No description provided for @playlistItemRestoreMessage.
  ///
  /// In es, this message translates to:
  /// **'«{name}» ya no está en la biblioteca. La playlist sigue usando su última versión. Para editarla, restaurala en la biblioteca.'**
  String playlistItemRestoreMessage(String name);

  /// No description provided for @playlistItemRestored.
  ///
  /// In es, this message translates to:
  /// **'«{name}» restaurada en la biblioteca'**
  String playlistItemRestored(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
