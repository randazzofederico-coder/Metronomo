// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Metronome';

  @override
  String get languageSystem => 'System language';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get soundSetClasico => 'Classic';

  @override
  String get soundSetMadera => 'Woodblock';

  @override
  String get soundSetClaves => 'Claves';

  @override
  String get soundSetBeep => 'Beep';

  @override
  String get soundSetHihat => 'Hi-hat';

  @override
  String get soundSetBombo => 'Kick drum';

  @override
  String get soundSetRedoblante => 'Snare';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonOk => 'OK';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonBack => 'Back';

  @override
  String get commonShare => 'Share';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonName => 'Name';

  @override
  String get homeTabPlay => 'Play';

  @override
  String get homeTabLibrary => 'Library';

  @override
  String get homeTabSettings => 'Settings';

  @override
  String get updateRequiredTitle => 'Update Required';

  @override
  String get updateDefaultMessage =>
      'A new version is available.\nUpdate to keep using Metrónomo.';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String get updateButton => 'Update';

  @override
  String get shareNativeFailedCopied =>
      'Couldn\'t open the share menu. We copied the link instead.';

  @override
  String get shareGeneratingLink => 'Generating link…';

  @override
  String get shareLinkCreateFailed => 'Couldn\'t create the link.';

  @override
  String get shareShareVia => 'SHARE VIA…';

  @override
  String get shareLinkCopied => 'LINK COPIED!';

  @override
  String get shareCopyLink => 'COPY LINK';

  @override
  String get shareHeadingPattern => 'Share pattern';

  @override
  String get shareHeadingSession => 'Share session';

  @override
  String get shareHeadingPlaylist => 'Share playlist';

  @override
  String shareSubtitlePattern(String name, String structure) {
    return '“$name” · $structure';
  }

  @override
  String shareSubtitleSession(String name, int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patterns',
      one: '1 pattern',
    );
    return '“$name” · $bpm BPM · $_temp0';
  }

  @override
  String shareSubtitlePlaylist(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '“$name” · $_temp0';
  }

  @override
  String get shareErrorConnect =>
      'Couldn\'t connect to the server to create the link.';

  @override
  String get shareErrorPermission =>
      'The server rejected the link (permissions).';

  @override
  String get shareErrorNetwork =>
      'Couldn\'t create the link. Check your connection.';

  @override
  String shareTitlePattern(String name) {
    return 'Pattern: $name';
  }

  @override
  String shareTitleSession(String name) {
    return 'Session: $name';
  }

  @override
  String shareTitlePlaylist(String name) {
    return 'Playlist: $name';
  }

  @override
  String shareMessagePattern(String name, String structure) {
    return '🎵 Check out the pattern “$name” ($structure) on Metronome:';
  }

  @override
  String shareMessageSession(String name, int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patterns',
      one: '1 pattern',
    );
    return '🎵 Check out the session “$name” ($bpm BPM · $_temp0) on Metronome:';
  }

  @override
  String shareMessagePlaylist(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '🎵 Check out the playlist “$name” ($_temp0) on Metronome:';
  }

  @override
  String get patternDefaultName => 'Pattern';

  @override
  String patternNumbered(int number) {
    return 'Pattern $number';
  }

  @override
  String patternCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get sessionDefaultDescription =>
      'Default session with a 3/4 and 6/8 polyrhythm';

  @override
  String metronomePatternAddedToSession(String name) {
    return '“$name” added to the session';
  }

  @override
  String get metronomeOpeningSharedLink => 'Opening shared link...';

  @override
  String get metronomeShareInvalid =>
      'This shared link is invalid or has expired.';

  @override
  String get metronomeShareImportFailed =>
      'Couldn\'t import the shared content.';

  @override
  String get metronomeReceivedPattern => 'Pattern received';

  @override
  String get metronomeReceivedSession => 'Session received';

  @override
  String get metronomeReceivedPlaylist => 'Playlist received';

  @override
  String get metronomeImportAlreadyInLibrary =>
      'It was already in your library.';

  @override
  String get metronomeImportAddedPattern => 'Added to your library.';

  @override
  String metronomeImportAddedSession(int patternCount) {
    String _temp0 = intl.Intl.pluralLogic(
      patternCount,
      locale: localeName,
      other: '$patternCount patterns',
      one: '1 pattern',
    );
    return 'Added to your library ($_temp0).';
  }

  @override
  String metronomeImportAddedPlaylist(int sessionCount, int patternCount) {
    String _temp0 = intl.Intl.pluralLogic(
      sessionCount,
      locale: localeName,
      other: '$sessionCount sessions',
      one: '1 session',
    );
    String _temp1 = intl.Intl.pluralLogic(
      patternCount,
      locale: localeName,
      other: '$patternCount patterns',
      one: '1 pattern',
    );
    return 'Added to your library ($_temp0, $_temp1).';
  }

  @override
  String metronomeImportOpenPrompt(String name, String status) {
    return '“$name”\n$status\n\nOpen it now?';
  }

  @override
  String get metronomeImportSaveOnly => 'JUST SAVE';

  @override
  String get metronomeImportOpen => 'OPEN';

  @override
  String get metronomeUntitled => 'Untitled';

  @override
  String get metronomeUnsavedTitle => 'Unsaved changes';

  @override
  String metronomeUnsavedMessage(String name) {
    return 'The session “$name” has unsaved changes. What do you want to do before continuing?';
  }

  @override
  String get metronomeDiscard => 'DISCARD';

  @override
  String get metronomeDefaultSessionName => 'Session';

  @override
  String get metronomeNewSessionSnack => 'New session';

  @override
  String metronomePatternRemoved(String name) {
    return '“$name” removed from the session';
  }

  @override
  String metronomeSessionSaved(String name) {
    return '“$name” saved';
  }

  @override
  String get metronomeSaveSessionTitle => 'Save Session';

  @override
  String get metronomeSessionNameLabel => 'Session Name';

  @override
  String get metronomeDescriptionLabel => 'Description (optional)';

  @override
  String get metronomeLoadSessionTitle => 'Load Session';

  @override
  String metronomeSessionDeleted(String name) {
    return '“$name” deleted';
  }

  @override
  String get metronomeNoSessions => 'No saved sessions.';

  @override
  String metronomeSessionSubtitle(int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$bpm BPM • $_temp0';
  }

  @override
  String get metronomeShareSession => 'Share session';

  @override
  String get metronomeDeleteSession => 'Delete session';

  @override
  String metronomeDeleteSessionConfirm(String name) {
    return 'Delete “$name” from your library?';
  }

  @override
  String get metronomeLoadPatternTitle => 'Load Pattern';

  @override
  String metronomePatternDeletedFromLibrary(String name) {
    return '“$name” deleted from the library';
  }

  @override
  String get metronomeNoPatterns => 'No patterns in the library.';

  @override
  String metronomeStructureLabel(String structure) {
    return 'Structure: $structure';
  }

  @override
  String get metronomeSharePattern => 'Share pattern';

  @override
  String get metronomeDeletePatternFromLibrary =>
      'Delete pattern from the library';

  @override
  String get metronomeTitle => 'METRONOME';

  @override
  String get metronomeSaveSessionTooltip => 'Save session';

  @override
  String get metronomeMoreOptions => 'More options';

  @override
  String get metronomeMenuNewSession => 'New session';

  @override
  String get metronomeMenuOpenSession => 'Open session…';

  @override
  String get metronomeMenuSaveAs => 'Save as…';

  @override
  String get metronomeMenuPlaylists => 'Playlists';

  @override
  String get metronomeMenuSettings => 'Settings';

  @override
  String metronomeDefaultPatternName(int number) {
    return 'Pattern $number';
  }

  @override
  String get metronomeAdd => 'ADD';

  @override
  String get metronomeLibrary => 'LIBRARY';

  @override
  String get metronomeTapToRename => 'Tap to rename';

  @override
  String get metronomePatternOptions => 'Pattern options';

  @override
  String get metronomeSaveToLibrary => 'Save to library';

  @override
  String get metronomeDuplicate => 'Duplicate';

  @override
  String get metronomeRemoveFromSession => 'Remove from session';

  @override
  String get metronomeRenamePatternTitle => 'Rename pattern';

  @override
  String metronomePatternUpdatedInLibrary(String name) {
    return '“$name” updated in the library';
  }

  @override
  String metronomePatternSavedToLibrary(String name) {
    return '“$name” saved to the library';
  }

  @override
  String metronomePatternSoundTooltip(String sound) {
    return 'Pattern sound: $sound';
  }

  @override
  String metronomeGlobalSoundTooltip(String sound) {
    return 'Sound: $sound (global)';
  }

  @override
  String metronomeSoundGlobal(String sound) {
    return 'Global ($sound)';
  }

  @override
  String get metronomeStructureHint => 'e.g. 3+2';

  @override
  String get transportTapToTypeTempo => 'Tap to type the tempo';

  @override
  String transportTempoSemantics(int bpm) {
    return 'Tempo $bpm BPM. Tap to type it';
  }

  @override
  String transportStepUp(int amount) {
    return 'Up $amount BPM (hold to repeat)';
  }

  @override
  String transportStepDown(int amount) {
    return 'Down $amount BPM (hold to repeat)';
  }

  @override
  String get transportTempoTitle => 'Tempo';

  @override
  String get transportStop => 'Stop';

  @override
  String get transportPlay => 'Play';

  @override
  String get transportTapTempo => 'Tap tempo';

  @override
  String get transportTap => 'TAP';

  @override
  String get macroCycleTitle => 'MACRO CYCLE';

  @override
  String macroBeatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beats',
      one: '1 Beat',
    );
    return '$_temp0';
  }

  @override
  String get macroLegendAccent => 'Accent';

  @override
  String get macroLegendNormal => 'Normal';

  @override
  String get macroLegendSoft => 'Soft';

  @override
  String get macroLegendSilence => 'Rest';

  @override
  String get macroEditHints =>
      '· Tap a cell to change it · Hold and drag for volume';

  @override
  String mixerVolumeTooltip(int percent) {
    return 'Volume $percent% (drag)';
  }

  @override
  String get mixerMute => 'Mute';

  @override
  String get mixerSolo => 'Solo';

  @override
  String get keypadShortcutsHint => 'Enter confirms · Esc cancels · Tab next';

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get settingsPlaybackTitle => 'Playback';

  @override
  String get settingsBackgroundPlaybackTitle => 'Background playback';

  @override
  String get settingsBackgroundPlaybackSubtitle =>
      'The metronome keeps playing when the app is minimized';

  @override
  String get settingsKeepScreenOnTitle => 'Keep screen on';

  @override
  String get settingsKeepScreenOnSubtitle =>
      'Prevents the device from locking automatically';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Interface language';

  @override
  String get settingsSoundSetTitle => 'Sound Set';

  @override
  String get settingsRandomSilenceTitle => 'Random Silences';

  @override
  String get settingsRandomSilenceSubtitle =>
      'Percentage of beats that are randomly muted';

  @override
  String get settingsUiScaleTitle => 'Interface Size';

  @override
  String get settingsInstallTitle => 'Install App';

  @override
  String get settingsInstallSubtitle => 'Install the metronome on your device';

  @override
  String get settingsInstalledTitle => 'App Installed';

  @override
  String get settingsInstalledMessage =>
      'You\'re using the installed version of Metronome.';

  @override
  String get settingsInstallPrompt =>
      'Install Metronome on your device for quick access and offline use.';

  @override
  String get settingsInstallButton => 'Install';

  @override
  String get settingsInstallManualIntro =>
      'You can install this app from your browser menu:';

  @override
  String get settingsInstallStepChromeAndroid =>
      'Menu ⋮ → \"Install app\" or \"Add to Home screen\"';

  @override
  String get settingsInstallStepChromePc =>
      'Install icon in the address bar or Menu ⋮ → \"Install app\"';

  @override
  String get settingsInstallStepSafariIos =>
      'Tap the Share button → \"Add to Home Screen\"';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutDevelopedBy => 'Developed by Federico Randazzo';

  @override
  String get settingsAboutVisitWebsite => 'Visit Website';

  @override
  String get settingsForumTitle => 'Community';

  @override
  String get settingsForumSubtitle =>
      'Questions, suggestions and news in the forum';

  @override
  String get settingsForumButton => 'Go to Forum';

  @override
  String get libraryTitle => 'LIBRARY';

  @override
  String get librarySearchHint => 'Search by name…';

  @override
  String get librarySearch => 'Search';

  @override
  String get libraryCloseSearch => 'Close search';

  @override
  String get libraryTabSessions => 'Sessions';

  @override
  String get libraryTabPatterns => 'Patterns';

  @override
  String get libraryTabPlaylists => 'Playlists';

  @override
  String get libraryNewSession => 'New session';

  @override
  String get libraryNoSessions => 'No saved sessions';

  @override
  String libraryNoSessionsMatch(String query) {
    return 'No session matches “$query”';
  }

  @override
  String get libraryNoSessionsHint =>
      'Build a session in Play and save it with 💾';

  @override
  String librarySessionSubtitle(int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patterns',
      one: '1 pattern',
    );
    return '$bpm BPM · $_temp0';
  }

  @override
  String get libraryInPlayBadge => 'In Play';

  @override
  String get libraryOpenInPlay => 'Open in Play';

  @override
  String get libraryDuplicate => 'Duplicate';

  @override
  String librarySessionCreated(String name) {
    return '“$name” created';
  }

  @override
  String get libraryRenameSession => 'Rename session';

  @override
  String get libraryDeleteSession => 'Delete session';

  @override
  String libraryDeleteSessionConfirm(String name) {
    return 'Delete “$name” from your library?';
  }

  @override
  String librarySessionDeleted(String name) {
    return '“$name” deleted';
  }

  @override
  String get libraryNoPatterns => 'The pattern library is empty';

  @override
  String libraryNoPatternsMatch(String query) {
    return 'No pattern matches “$query”';
  }

  @override
  String get libraryNoPatternsHint =>
      'In Play, use ⋮ → “Save to library” on a pattern';

  @override
  String get libraryAddToSession => 'Add to session';

  @override
  String get libraryRemoveFromLibrary => 'Remove from library';

  @override
  String get libraryRenamePattern => 'Rename pattern';

  @override
  String libraryPatternRemoved(String name) {
    return '“$name” removed from the library';
  }

  @override
  String get libraryOptions => 'Options';

  @override
  String get playlistsTitle => 'PLAYLISTS';

  @override
  String get playlistsNewTitle => 'New Playlist';

  @override
  String get playlistsEditTitle => 'Edit Playlist';

  @override
  String get playlistsDescriptionLabel => 'Description (optional)';

  @override
  String get playlistsUpdateButton => 'UPDATE';

  @override
  String get playlistsDeleteTitle => 'Delete playlist';

  @override
  String playlistsDeleteConfirm(String name) {
    return 'Delete “$name”? The sessions it contains won\'t be deleted.';
  }

  @override
  String playlistsDeleted(String name) {
    return '“$name” deleted';
  }

  @override
  String get playlistsNewButton => 'New playlist';

  @override
  String get playlistsNoMatch => 'No playlist matches your search';

  @override
  String get playlistsEmpty => 'No playlists';

  @override
  String get playlistsEmptyHint =>
      'Create a playlist to organize your sessions';

  @override
  String get playlistsCreateButton => 'CREATE PLAYLIST';

  @override
  String playlistsSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get playlistsOptions => 'Playlist options';

  @override
  String get playlistsDeletedSessionChip => '(deleted)';

  @override
  String playlistsMoreCount(int count) {
    return '+$count more';
  }

  @override
  String get playlistsAddSession => 'Add Session';

  @override
  String get playlistsAddSessionEmpty =>
      'No saved sessions.\nCreate sessions from the metronome.';

  @override
  String playlistsSessionSubtitle(int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$bpm BPM • $_temp0';
  }

  @override
  String get playlistsNotFoundTitle => 'Playlist not found';

  @override
  String get playlistsNotFoundMessage => 'This playlist was deleted.';

  @override
  String get playlistsPlay => 'Play';

  @override
  String get playlistsDetailEmpty => 'Empty playlist';

  @override
  String get playlistsDetailEmptyHint => 'Add sessions with the + button';

  @override
  String get playlistsAddSessionButton => 'ADD SESSION';

  @override
  String get playlistsDeletedSession => '(deleted session)';

  @override
  String get playlistsRemoveSession => 'Remove from playlist';

  @override
  String get playlistsRemoved => 'Removed from playlist';

  @override
  String playlistsSessionRemoved(String name) {
    return '“$name” removed from the playlist';
  }
}
