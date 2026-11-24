import 'dart:async';

import 'package:fede_apps_core/fede_apps_core.dart' show UsageReporter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';
import 'package:metronomo_standalone/services/file_export_service.dart';
import 'package:metronomo_standalone/services/midi_export_service.dart';
import 'package:metronomo_standalone/utils/bpm_scale.dart';

typedef MidiFileExporter = Future<FileExportOutcome> Function({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? shareTitle,
  Rect? shareOrigin,
});

/// Opens the MIDI export configuration bottom sheet.
///
/// Lets the user pick cycle repetitions, BPM (for standalone patterns), and
/// MIDI channel layout (GM Percussion Ch 10 vs Multi-channel Ch 1–16 with an
/// explanatory `?` dialog), then builds and exports the `.mid` or `.zip` file.
Future<void> showMidiExportSheet(
  BuildContext context, {
  required String heading,
  required String subtitle,
  required String fileName,
  required bool isZip,
  int? initialBpm,
  int? fixedBpm,
  double? singleCycleBeats,
  int? sessionCount,
  required Uint8List Function(MidiExportOptions options, int bpm) buildBytes,
  required String analyticsType,
  MidiFileExporter? exportFile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MidiExportSheet(
      heading: heading,
      subtitle: subtitle,
      fileName: fileName,
      isZip: isZip,
      initialBpm: initialBpm,
      fixedBpm: fixedBpm,
      singleCycleBeats: singleCycleBeats,
      sessionCount: sessionCount,
      buildBytes: buildBytes,
      analyticsType: analyticsType,
      exportFile: exportFile ?? exportBytesAsFile,
    ),
  );
}

class _MidiExportSheet extends StatefulWidget {
  final String heading;
  final String subtitle;
  final String fileName;
  final bool isZip;
  final int? initialBpm;
  final int? fixedBpm;
  final double? singleCycleBeats;
  final int? sessionCount;
  final Uint8List Function(MidiExportOptions options, int bpm) buildBytes;
  final String analyticsType;
  final MidiFileExporter exportFile;

  const _MidiExportSheet({
    required this.heading,
    required this.subtitle,
    required this.fileName,
    required this.isZip,
    this.initialBpm,
    this.fixedBpm,
    this.singleCycleBeats,
    this.sessionCount,
    required this.buildBytes,
    required this.analyticsType,
    required this.exportFile,
  });

  @override
  State<_MidiExportSheet> createState() => _MidiExportSheetState();
}

class _MidiExportSheetState extends State<_MidiExportSheet> {
  static const List<int> _cycleChoices = [1, 2, 4, 8, 16];

  late int _bpm;
  late final TextEditingController _bpmController;
  late final FocusNode _bpmFocusNode;

  int _repetitions = 1;
  MidiChannelMode _channelMode = MidiChannelMode.gmPercussion;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bpm = (widget.initialBpm ?? widget.fixedBpm ?? 120)
        .clamp(BpmScale.minBpm, BpmScale.maxBpm);
    _bpmController = TextEditingController(text: '$_bpm');
    _bpmFocusNode = FocusNode()
      ..addListener(() {
        if (!_bpmFocusNode.hasFocus) {
          _syncBpmText();
        }
      });
  }

  @override
  void dispose() {
    _bpmController.dispose();
    _bpmFocusNode.dispose();
    super.dispose();
  }

  void _syncBpmText() {
    final parsed = int.tryParse(_bpmController.text.trim());
    if (parsed != null) {
      _bpm = parsed.clamp(BpmScale.minBpm, BpmScale.maxBpm);
    }
    final text = '$_bpm';
    if (_bpmController.text != text) {
      _bpmController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _stepBpm(int delta) {
    setState(() {
      _bpm = (_bpm + delta).clamp(BpmScale.minBpm, BpmScale.maxBpm);
      final text = '$_bpm';
      _bpmController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _onBpmTextChanged(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    setState(() {
      _bpm = parsed.clamp(BpmScale.minBpm, BpmScale.maxBpm);
    });
  }

  String _formatSummary(AppLocalizations l10n) {
    if (widget.sessionCount != null) {
      return l10n.midiExportPlaylistSummary(
          widget.sessionCount!, widget.fileName);
    }
    final cycleBeats = widget.singleCycleBeats;
    if (cycleBeats == null || _bpm <= 0) return widget.fileName;

    final totalBeats = cycleBeats * _repetitions;
    final beatsLabel = (totalBeats - totalBeats.round()).abs() < 1e-6
        ? '${totalBeats.round()}'
        : totalBeats.toStringAsFixed(1);
    final seconds = totalBeats * 60.0 / _bpm;
    final secondsLabel = seconds < 10
        ? seconds.toStringAsFixed(1)
        : seconds.round().toString();
    return l10n.midiExportDurationSummary(beatsLabel, secondsLabel);
  }

  Future<void> _showModeHelp(BuildContext context) {
    final l10n = context.l10n;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.primary(context);

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: accent, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.midiExportModeHelpTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.midiExportModeHelpGmTitle,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.midiExportModeHelpGmBody,
                style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.midiExportModeHelpMultiTitle,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.midiExportModeHelpMultiBody,
                style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonOk,
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext buttonContext) async {
    if (_exporting) return;
    _syncBpmText();

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final options = MidiExportOptions(
        repetitions: _repetitions,
        channelMode: _channelMode,
      );
      final bytes = widget.buildBytes(options, _bpm);
      final outcome = await widget.exportFile(
        bytes: bytes,
        fileName: widget.fileName,
        mimeType: widget.isZip ? 'application/zip' : 'audio/midi',
        shareTitle: widget.fileName,
        shareOrigin: origin,
      );
      unawaited(UsageReporter.instance
          .trackEvent('midi-export/${widget.analyticsType}'));

      if (!mounted) return;
      Navigator.pop(context);
      if (outcome == FileExportOutcome.downloaded) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.midiExportDownloaded(widget.fileName))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _error = l10n.midiExportFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.primary(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final actionLabel = kIsWeb
        ? (widget.isZip ? l10n.midiExportDownloadZip : l10n.midiExportDownloadMid)
        : (widget.isZip ? l10n.midiExportActionZip : l10n.midiExportActionMid);
    final actionIcon = kIsWeb ? Icons.download_rounded : Icons.ios_share;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.heading,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: TextStyle(color: textSecondary)),
            const SizedBox(height: 18),

            // Tempo editor for standalone patterns
            if (widget.initialBpm != null) ...[
              Text(
                l10n.midiExportBpmLabel,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _bpmStepButton(context, '-5', () => _stepBpm(-5)),
                    _bpmStepButton(context, '-1', () => _stepBpm(-1)),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _bpmController,
                        focusNode: _bpmFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                        onChanged: _onBpmTextChanged,
                        onSubmitted: (_) => _syncBpmText(),
                      ),
                    ),
                    _bpmStepButton(context, '+1', () => _stepBpm(1)),
                    _bpmStepButton(context, '+5', () => _stepBpm(5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Cycle repetitions
            Text(
              l10n.midiExportCyclesLabel,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cycleChoices.map((count) {
                final selected = _repetitions == count;
                return ChoiceChip(
                  label: Text('${count}x'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: accent.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surfaceHighlight(context),
                  side: BorderSide(
                    color: selected ? accent : AppColors.border(context),
                    width: selected ? 1.5 : 1,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? accent : textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => _repetitions = count),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              _formatSummary(l10n),
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // MIDI format selector + visible '?' help button
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.midiExportChannelModeLabel,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('midi_mode_help_button'),
                  icon: Icon(Icons.help_outline_rounded, color: accent, size: 22),
                  tooltip: l10n.midiExportModeHelpTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showModeHelp(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _ModeOptionCard(
                    label: l10n.midiExportModeGm,
                    icon: Icons.music_note_rounded,
                    selected: _channelMode == MidiChannelMode.gmPercussion,
                    onTap: () => setState(
                        () => _channelMode = MidiChannelMode.gmPercussion),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeOptionCard(
                    label: l10n.midiExportModeMulti,
                    icon: Icons.tune_rounded,
                    selected: _channelMode == MidiChannelMode.multiChannel,
                    onTap: () => setState(
                        () => _channelMode = MidiChannelMode.multiChannel),
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.error_outline,
                      color: AppColors.accentRed(context), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: AppColors.accentRed(context),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            Builder(
              builder: (buttonCtx) => FilledButton.icon(
                onPressed: _exporting ? null : () => _handleExport(buttonCtx),
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bpmStepButton(
      BuildContext context, String label, VoidCallback onPressed) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOptionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.16)
          : AppColors.surfaceHighlight(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent : AppColors.border(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? accent : textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? textPrimary : textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
