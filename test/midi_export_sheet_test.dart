import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';
import 'package:metronomo_standalone/services/file_export_service.dart';
import 'package:metronomo_standalone/services/midi_export_service.dart';
import 'package:metronomo_standalone/theme/app_theme.dart';
import 'package:metronomo_standalone/widgets/midi_export_sheet.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    locale: const Locale('es'),
    supportedLocales: kSupportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

void main() {
  group('MidiExportSheet', () {
    testWidgets('shows controls, opens ? help dialog, and passes chosen options',
        (tester) async {
      MidiExportOptions? capturedOptions;
      int? capturedBpm;
      String? exportedName;
      String? exportedMime;

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMidiExportSheet(
                context,
                heading: 'Exportar patrón MIDI',
                subtitle: '«Clave» · 4',
                fileName: 'Clave.mid',
                isZip: false,
                initialBpm: 120,
                singleCycleBeats: 4.0,
                analyticsType: 'pattern',
                buildBytes: (options, bpm) {
                  capturedOptions = options;
                  capturedBpm = bpm;
                  return Uint8List.fromList([1, 2, 3]);
                },
                exportFile: ({
                  required bytes,
                  required fileName,
                  required mimeType,
                  shareTitle,
                  shareOrigin,
                }) async {
                  exportedName = fileName;
                  exportedMime = mimeType;
                  return FileExportOutcome.shared;
                },
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Sheet displays BPM controls, repetitions, mode selector, and '?' button.
      expect(find.text('Tempo (BPM)'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('4x'), findsOneWidget);
      expect(find.text('Percusión GM (Canal 10)'), findsOneWidget);
      expect(find.text('Multicanal (Canales 1–16)'), findsOneWidget);
      expect(find.byKey(const ValueKey('midi_mode_help_button')), findsOneWidget);

      // Tap '?' to open the explanation dialog.
      await tester.tap(find.byKey(const ValueKey('midi_mode_help_button')));
      await tester.pumpAndSettle();
      expect(find.text('¿Por qué hay dos opciones?'), findsOneWidget);
      expect(find.textContaining('Canal 10 estándar'), findsOneWidget);
      expect(find.textContaining('propio canal MIDI'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Adjust BPM (+5), repetitions (4x), and channel mode (Multicanal).
      await tester.tap(find.text('+5'));
      await tester.pump();
      await tester.tap(find.text('4x'));
      await tester.pump();
      await tester.tap(find.text('Multicanal (Canales 1–16)'));
      await tester.pump();

      expect(find.textContaining('16 pulsos'), findsOneWidget);

      await tester.tap(find.text('EXPORTAR .MID'));
      await tester.pumpAndSettle();

      expect(capturedBpm, 125);
      expect(capturedOptions?.repetitions, 4);
      expect(capturedOptions?.channelMode, MidiChannelMode.multiChannel);
      expect(exportedName, 'Clave.mid');
      expect(exportedMime, 'audio/midi');
    });

    testWidgets('playlist mode hides BPM editor and exports .zip with snackbar',
        (tester) async {
      String? exportedMime;

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMidiExportSheet(
                context,
                heading: 'Exportar playlist MIDI',
                subtitle: '«Setlist» · 2 sesiones (.zip)',
                fileName: 'Setlist.zip',
                isZip: true,
                sessionCount: 2,
                analyticsType: 'playlist',
                buildBytes: (_, _) => Uint8List.fromList([0x50, 0x4B]),
                exportFile: ({
                  required bytes,
                  required fileName,
                  required mimeType,
                  shareTitle,
                  shareOrigin,
                }) async {
                  exportedMime = mimeType;
                  return FileExportOutcome.downloaded;
                },
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Tempo (BPM)'), findsNothing);
      expect(find.text('2 archivos .mid en «Setlist.zip»'), findsOneWidget);

      await tester.tap(find.text('EXPORTAR .ZIP'));
      await tester.pumpAndSettle();

      expect(exportedMime, 'application/zip');
      expect(find.text('Descargado: Setlist.zip'), findsOneWidget);
    });

    testWidgets('shows error inside sheet when export fails', (tester) async {
      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMidiExportSheet(
                context,
                heading: 'Exportar sesión MIDI',
                subtitle: '«Test» · 120 BPM · 1 patrón',
                fileName: 'Test.mid',
                isZip: false,
                fixedBpm: 120,
                singleCycleBeats: 4.0,
                analyticsType: 'session',
                buildBytes: (_, _) => Uint8List.fromList([1]),
                exportFile: ({
                  required bytes,
                  required fileName,
                  required mimeType,
                  shareTitle,
                  shareOrigin,
                }) async {
                  throw Exception('disk full');
                },
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPORTAR .MID'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo exportar el archivo MIDI.'), findsOneWidget);
      // Sheet remains open so the user can retry.
      expect(find.text('Exportar sesión MIDI'), findsOneWidget);
    });
  });
}
