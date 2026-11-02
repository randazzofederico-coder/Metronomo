// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Metrónomo';

  @override
  String get languageSystem => 'Idioma del sistema';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get soundSetClasico => 'Clásico';

  @override
  String get soundSetMadera => 'Madera';

  @override
  String get soundSetClaves => 'Claves';

  @override
  String get soundSetBeep => 'Beep';

  @override
  String get soundSetHihat => 'Hi-hat';

  @override
  String get soundSetBombo => 'Bombo';

  @override
  String get soundSetRedoblante => 'Redoblante';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonAccept => 'Aceptar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonShare => 'Compartir';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get commonName => 'Nombre';

  @override
  String get homeTabPlay => 'Tocar';

  @override
  String get homeTabLibrary => 'Biblioteca';

  @override
  String get homeTabSettings => 'Ajustes';

  @override
  String get updateRequiredTitle => 'Actualización Necesaria';

  @override
  String get updateDefaultMessage =>
      'Hay una nueva versión disponible.\nActualizá para seguir usando Metrónomo.';

  @override
  String get updateDownloading => 'Descargando actualización…';

  @override
  String get updateButton => 'Actualizar';

  @override
  String get shareNativeFailedCopied =>
      'No se pudo abrir el menú de compartir. Copiamos el link.';

  @override
  String get shareGeneratingLink => 'Generando link…';

  @override
  String get shareLinkCreateFailed => 'No se pudo crear el link.';

  @override
  String get shareShareVia => 'COMPARTIR EN…';

  @override
  String get shareLinkCopied => '¡LINK COPIADO!';

  @override
  String get shareCopyLink => 'COPIAR LINK';

  @override
  String get shareHeadingPattern => 'Compartir patrón';

  @override
  String get shareHeadingSession => 'Compartir sesión';

  @override
  String get shareHeadingPlaylist => 'Compartir playlist';

  @override
  String shareSubtitlePattern(String name, String structure) {
    return '«$name» · $structure';
  }

  @override
  String shareSubtitleSession(String name, int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patrones',
      one: '1 patrón',
    );
    return '«$name» · $bpm BPM · $_temp0';
  }

  @override
  String shareSubtitlePlaylist(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '1 sesión',
    );
    return '«$name» · $_temp0';
  }

  @override
  String get shareErrorConnect =>
      'No se pudo conectar con el servidor para crear el link.';

  @override
  String get shareErrorPermission => 'El servidor rechazó el link (permisos).';

  @override
  String get shareErrorNetwork =>
      'No se pudo crear el link. Revisá tu conexión.';

  @override
  String shareTitlePattern(String name) {
    return 'Patrón: $name';
  }

  @override
  String shareTitleSession(String name) {
    return 'Sesión: $name';
  }

  @override
  String shareTitlePlaylist(String name) {
    return 'Playlist: $name';
  }

  @override
  String shareMessagePattern(String name, String structure) {
    return '🎵 Te comparto el patrón «$name» ($structure) en Metrónomo:';
  }

  @override
  String shareMessageSession(String name, int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patrones',
      one: '1 patrón',
    );
    return '🎵 Te comparto la sesión «$name» ($bpm BPM · $_temp0) en Metrónomo:';
  }

  @override
  String shareMessagePlaylist(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '1 sesión',
    );
    return '🎵 Te comparto la playlist «$name» ($_temp0) en Metrónomo:';
  }

  @override
  String get patternDefaultName => 'Patrón';

  @override
  String patternNumbered(int number) {
    return 'Patrón $number';
  }

  @override
  String patternCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String get sessionDefaultDescription =>
      'Sesión por defecto con birritmia de 3/4 y 6/8';

  @override
  String metronomePatternAddedToSession(String name) {
    return '«$name» agregado a la sesión';
  }

  @override
  String get metronomeOpeningSharedLink => 'Abriendo link compartido...';

  @override
  String get metronomeShareInvalid =>
      'El enlace compartido no es válido o ha expirado.';

  @override
  String get metronomeShareImportFailed =>
      'No se pudo importar el contenido compartido.';

  @override
  String get metronomeReceivedPattern => 'Patrón recibido';

  @override
  String get metronomeReceivedSession => 'Sesión recibida';

  @override
  String get metronomeReceivedPlaylist => 'Playlist recibida';

  @override
  String get metronomeImportAlreadyInLibrary => 'Ya estaba en tu biblioteca.';

  @override
  String get metronomeImportAddedPattern => 'Se agregó a tu biblioteca.';

  @override
  String metronomeImportAddedSession(int patternCount) {
    String _temp0 = intl.Intl.pluralLogic(
      patternCount,
      locale: localeName,
      other: '$patternCount patrones',
      one: '1 patrón',
    );
    return 'Se agregó a tu biblioteca ($_temp0).';
  }

  @override
  String metronomeImportAddedPlaylist(int sessionCount, int patternCount) {
    String _temp0 = intl.Intl.pluralLogic(
      sessionCount,
      locale: localeName,
      other: '$sessionCount sesiones',
      one: '1 sesión',
    );
    String _temp1 = intl.Intl.pluralLogic(
      patternCount,
      locale: localeName,
      other: '$patternCount patrones',
      one: '1 patrón',
    );
    return 'Se agregó a tu biblioteca ($_temp0, $_temp1).';
  }

  @override
  String metronomeImportOpenPrompt(String name, String status) {
    return '«$name»\n$status\n\n¿Querés abrirlo ahora?';
  }

  @override
  String get metronomeImportSaveOnly => 'SOLO GUARDAR';

  @override
  String get metronomeImportOpen => 'ABRIR';

  @override
  String get metronomeUntitled => 'Sin Título';

  @override
  String get metronomeUnsavedTitle => 'Cambios sin guardar';

  @override
  String metronomeUnsavedMessage(String name) {
    return 'La sesión «$name» tiene cambios sin guardar. ¿Qué querés hacer antes de continuar?';
  }

  @override
  String get metronomeDiscard => 'DESCARTAR';

  @override
  String get metronomeDefaultSessionName => 'Sesión';

  @override
  String get metronomeNewSessionSnack => 'Sesión nueva';

  @override
  String metronomePatternRemoved(String name) {
    return '«$name» quitado de la sesión';
  }

  @override
  String metronomeSessionSaved(String name) {
    return '«$name» guardada';
  }

  @override
  String get metronomeSaveSessionTitle => 'Guardar Sesión';

  @override
  String get metronomeSessionNameLabel => 'Nombre de la Sesión';

  @override
  String get metronomeDescriptionLabel => 'Descripción (opcional)';

  @override
  String get metronomeLoadSessionTitle => 'Cargar Sesión';

  @override
  String metronomeSessionDeleted(String name) {
    return '«$name» eliminada';
  }

  @override
  String get metronomeNoSessions => 'No hay sesiones guardadas.';

  @override
  String metronomeSessionSubtitle(int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$bpm BPM • $_temp0';
  }

  @override
  String get metronomeShareSession => 'Compartir sesión';

  @override
  String get metronomeDeleteSession => 'Eliminar sesión';

  @override
  String metronomeDeleteSessionConfirm(String name) {
    return '¿Eliminar «$name» de tu biblioteca?';
  }

  @override
  String get metronomeLoadPatternTitle => 'Cargar Patrón';

  @override
  String metronomePatternDeletedFromLibrary(String name) {
    return '«$name» eliminado de la librería';
  }

  @override
  String get metronomeNoPatterns => 'No hay patrones en la librería.';

  @override
  String metronomeStructureLabel(String structure) {
    return 'Estructura: $structure';
  }

  @override
  String get metronomeSharePattern => 'Compartir patrón';

  @override
  String get metronomeDeletePatternFromLibrary =>
      'Eliminar patrón de la librería';

  @override
  String get metronomeTitle => 'METRÓNOMO';

  @override
  String get metronomeSaveSessionTooltip => 'Guardar sesión';

  @override
  String get metronomeMoreOptions => 'Más opciones';

  @override
  String get metronomeMenuNewSession => 'Nueva sesión';

  @override
  String get metronomeMenuOpenSession => 'Abrir sesión…';

  @override
  String get metronomeMenuSaveAs => 'Guardar como…';

  @override
  String get metronomeMenuPlaylists => 'Playlists';

  @override
  String get metronomeMenuSettings => 'Ajustes';

  @override
  String metronomeDefaultPatternName(int number) {
    return 'Patrón $number';
  }

  @override
  String get metronomeAdd => 'AÑADIR';

  @override
  String get metronomeLibrary => 'LIBRERÍA';

  @override
  String get metronomeTapToRename => 'Tocá para renombrar';

  @override
  String get metronomePatternOptions => 'Opciones del patrón';

  @override
  String get metronomeSaveToLibrary => 'Guardar en la librería';

  @override
  String get metronomeDuplicate => 'Duplicar';

  @override
  String get metronomeRemoveFromSession => 'Quitar de la sesión';

  @override
  String get metronomeRenamePatternTitle => 'Renombrar patrón';

  @override
  String metronomePatternUpdatedInLibrary(String name) {
    return '«$name» actualizado en la librería';
  }

  @override
  String metronomePatternSavedToLibrary(String name) {
    return '«$name» guardado en la librería';
  }

  @override
  String metronomePatternSoundTooltip(String sound) {
    return 'Sonido del patrón: $sound';
  }

  @override
  String metronomeGlobalSoundTooltip(String sound) {
    return 'Sonido: $sound (global)';
  }

  @override
  String metronomeSoundGlobal(String sound) {
    return 'Global ($sound)';
  }

  @override
  String get metronomeStructureHint => 'Ej. 3+2';

  @override
  String get transportTapToTypeTempo => 'Tocá para escribir el tempo';

  @override
  String transportTempoSemantics(int bpm) {
    return 'Tempo $bpm BPM. Tocá para escribirlo';
  }

  @override
  String transportStepUp(int amount) {
    return 'Subir $amount BPM (mantené para repetir)';
  }

  @override
  String transportStepDown(int amount) {
    return 'Bajar $amount BPM (mantené para repetir)';
  }

  @override
  String get transportTempoTitle => 'Tempo';

  @override
  String get transportStop => 'Detener';

  @override
  String get transportPlay => 'Reproducir';

  @override
  String get transportTapTempo => 'Tap tempo';

  @override
  String get transportTap => 'TAP';

  @override
  String get macroCycleTitle => 'CICLO MACRO';

  @override
  String macroBeatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Pulsos',
      one: '1 Pulso',
    );
    return '$_temp0';
  }

  @override
  String get macroLegendAccent => 'Acento';

  @override
  String get macroLegendNormal => 'Normal';

  @override
  String get macroLegendSoft => 'Suave';

  @override
  String get macroLegendSilence => 'Silencio';

  @override
  String get macroEditHints =>
      '· Tocá una celda para cambiarla · Mantené y arrastrá para el volumen';

  @override
  String mixerVolumeTooltip(int percent) {
    return 'Volumen $percent% (arrastrá)';
  }

  @override
  String get mixerMute => 'Silenciar';

  @override
  String get mixerSolo => 'Solo';

  @override
  String get keypadShortcutsHint =>
      'Enter confirma · Esc cancela · Tab siguiente';

  @override
  String get settingsTitle => 'AJUSTES';

  @override
  String get settingsPlaybackTitle => 'Reproducción';

  @override
  String get settingsBackgroundPlaybackTitle => 'Reproducción en segundo plano';

  @override
  String get settingsBackgroundPlaybackSubtitle =>
      'El metrónomo sigue sonando al minimizar la app';

  @override
  String get settingsKeepScreenOnTitle => 'Mantener pantalla encendida';

  @override
  String get settingsKeepScreenOnSubtitle =>
      'Evita que el dispositivo se bloquee automáticamente';

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSubtitle => 'Idioma de la interfaz';

  @override
  String get settingsSoundSetTitle => 'Set de Sonidos';

  @override
  String get settingsRandomSilenceTitle => 'Silencios al Azar';

  @override
  String get settingsRandomSilenceSubtitle =>
      'Porcentaje de beats que se silencian aleatoriamente';

  @override
  String get settingsUiScaleTitle => 'Tamaño de la Interfaz';

  @override
  String get settingsInstallTitle => 'Instalar Aplicación';

  @override
  String get settingsInstallSubtitle =>
      'Instalá el metrónomo en tu dispositivo';

  @override
  String get settingsInstalledTitle => 'App Instalada';

  @override
  String get settingsInstalledMessage =>
      'Estás usando la versión instalada del Metrónomo.';

  @override
  String get settingsInstallPrompt =>
      'Instalá el Metrónomo en tu dispositivo para acceso rápido y uso sin conexión.';

  @override
  String get settingsInstallButton => 'Instalar';

  @override
  String get settingsInstallManualIntro =>
      'Podés instalar esta app desde el menú de tu navegador:';

  @override
  String get settingsInstallStepChromeAndroid =>
      'Menú ⋮ → \"Instalar aplicación\" o \"Añadir a pantalla de inicio\"';

  @override
  String get settingsInstallStepChromePc =>
      'Icono de instalación en la barra de direcciones o Menú ⋮ → \"Instalar app\"';

  @override
  String get settingsInstallStepSafariIos =>
      'Tocar el botón Compartir → \"Agregar a pantalla de inicio\"';

  @override
  String get settingsAboutTitle => 'Acerca de';

  @override
  String get settingsAboutDevelopedBy => 'Desarrollado por Federico Randazzo';

  @override
  String get settingsAboutVisitWebsite => 'Visitar Sitio Web';

  @override
  String get settingsForumTitle => 'Comunidad';

  @override
  String get settingsForumSubtitle =>
      'Consultas, sugerencias y novedades en el foro';

  @override
  String get settingsForumButton => 'Ir al Foro';

  @override
  String get libraryTitle => 'BIBLIOTECA';

  @override
  String get librarySearchHint => 'Buscar por nombre…';

  @override
  String get librarySearch => 'Buscar';

  @override
  String get libraryCloseSearch => 'Cerrar búsqueda';

  @override
  String get libraryTabSessions => 'Sesiones';

  @override
  String get libraryTabPatterns => 'Patrones';

  @override
  String get libraryTabPlaylists => 'Playlists';

  @override
  String get libraryNewSession => 'Nueva sesión';

  @override
  String get libraryNoSessions => 'No hay sesiones guardadas';

  @override
  String libraryNoSessionsMatch(String query) {
    return 'Ninguna sesión coincide con «$query»';
  }

  @override
  String get libraryNoSessionsHint =>
      'Armá una sesión en Tocar y guardala con 💾';

  @override
  String librarySessionSubtitle(int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patrones',
      one: '1 patrón',
    );
    return '$bpm BPM · $_temp0';
  }

  @override
  String get libraryInPlayBadge => 'En Tocar';

  @override
  String get libraryOpenInPlay => 'Abrir en Tocar';

  @override
  String get libraryDuplicate => 'Duplicar';

  @override
  String librarySessionCreated(String name) {
    return '«$name» creada';
  }

  @override
  String get libraryRenameSession => 'Renombrar sesión';

  @override
  String get libraryDeleteSession => 'Eliminar sesión';

  @override
  String libraryDeleteSessionConfirm(String name) {
    return '¿Eliminar «$name» de tu biblioteca?';
  }

  @override
  String librarySessionDeleted(String name) {
    return '«$name» eliminada';
  }

  @override
  String get libraryNoPatterns => 'La librería de patrones está vacía';

  @override
  String libraryNoPatternsMatch(String query) {
    return 'Ningún patrón coincide con «$query»';
  }

  @override
  String get libraryNoPatternsHint =>
      'En Tocar, usá ⋮ → «Guardar en la librería» en un patrón';

  @override
  String get libraryAddToSession => 'Agregar a la sesión';

  @override
  String get libraryRemoveFromLibrary => 'Eliminar de la librería';

  @override
  String get libraryRenamePattern => 'Renombrar patrón';

  @override
  String libraryPatternRemoved(String name) {
    return '«$name» eliminado de la librería';
  }

  @override
  String get libraryOptions => 'Opciones';

  @override
  String get playlistsTitle => 'PLAYLISTS';

  @override
  String get playlistsNewTitle => 'Nueva Playlist';

  @override
  String get playlistsEditTitle => 'Editar Playlist';

  @override
  String get playlistsDescriptionLabel => 'Descripción (opcional)';

  @override
  String get playlistsUpdateButton => 'ACTUALIZAR';

  @override
  String get playlistsDeleteTitle => 'Eliminar playlist';

  @override
  String playlistsDeleteConfirm(String name) {
    return '¿Eliminar «$name»? Las sesiones que contiene no se borran.';
  }

  @override
  String playlistsDeleted(String name) {
    return '«$name» eliminada';
  }

  @override
  String get playlistsNewButton => 'Nueva playlist';

  @override
  String get playlistsNoMatch => 'Ninguna playlist coincide con la búsqueda';

  @override
  String get playlistsEmpty => 'No hay playlists';

  @override
  String get playlistsEmptyHint =>
      'Creá una playlist para organizar tus sesiones';

  @override
  String get playlistsCreateButton => 'CREAR PLAYLIST';

  @override
  String playlistsSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '1 sesión',
    );
    return '$_temp0';
  }

  @override
  String get playlistsOptions => 'Opciones de la playlist';

  @override
  String get playlistsDeletedSessionChip => '(eliminada)';

  @override
  String playlistsMoreCount(int count) {
    return '+$count más';
  }

  @override
  String get playlistsAddSession => 'Agregar Sesión';

  @override
  String get playlistsAddSessionEmpty =>
      'No hay sesiones guardadas.\nCreá sesiones desde el metrónomo.';

  @override
  String playlistsSessionSubtitle(int bpm, int count) {
    return '$bpm BPM • $count pistas';
  }

  @override
  String get playlistsNotFoundTitle => 'Playlist no encontrada';

  @override
  String get playlistsNotFoundMessage => 'Esta playlist fue eliminada.';

  @override
  String get playlistsPlay => 'Reproducir';

  @override
  String get playlistsDetailEmpty => 'Playlist vacía';

  @override
  String get playlistsDetailEmptyHint => 'Agregá sesiones usando el botón +';

  @override
  String get playlistsAddSessionButton => 'AGREGAR SESIÓN';

  @override
  String get playlistsDeletedSession => '(sesión eliminada)';

  @override
  String get playlistsRemoveSession => 'Quitar de la playlist';

  @override
  String get playlistsRemoved => 'Quitada de la playlist';

  @override
  String playlistsSessionRemoved(String name) {
    return '«$name» quitada de la playlist';
  }
}
