import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/services/zip_builder.dart';

class _ParsedZipEntry {
  final String name;
  final Uint8List data;
  final int flags;
  final int method;
  final int crc;

  const _ParsedZipEntry({
    required this.name,
    required this.data,
    required this.flags,
    required this.method,
    required this.crc,
  });
}

List<_ParsedZipEntry> _parseZip(Uint8List zip) {
  final bd = ByteData.sublistView(zip);
  // Find End of Central Directory (0x06054b50) from end.
  var eocdOffset = -1;
  for (var i = zip.length - 22; i >= 0; i--) {
    if (bd.getUint32(i, Endian.little) == 0x06054b50) {
      eocdOffset = i;
      break;
    }
  }
  expect(eocdOffset, greaterThanOrEqualTo(0), reason: 'Missing EOCD signature');

  final diskEntries = bd.getUint16(eocdOffset + 8, Endian.little);
  final totalEntries = bd.getUint16(eocdOffset + 10, Endian.little);
  final cdSize = bd.getUint32(eocdOffset + 12, Endian.little);
  final cdOffset = bd.getUint32(eocdOffset + 16, Endian.little);
  expect(diskEntries, totalEntries);
  expect(cdOffset + cdSize, eocdOffset);

  final out = <_ParsedZipEntry>[];
  var cursor = cdOffset;
  for (var i = 0; i < totalEntries; i++) {
    expect(bd.getUint32(cursor, Endian.little), 0x02014b50,
        reason: 'Invalid CD header signature at $cursor');
    final cdFlags = bd.getUint16(cursor + 8, Endian.little);
    final cdMethod = bd.getUint16(cursor + 10, Endian.little);
    final cdCrc = bd.getUint32(cursor + 16, Endian.little);
    final compSize = bd.getUint32(cursor + 20, Endian.little);
    final uncompSize = bd.getUint32(cursor + 24, Endian.little);
    final nameLen = bd.getUint16(cursor + 28, Endian.little);
    final extraLen = bd.getUint16(cursor + 30, Endian.little);
    final commentLen = bd.getUint16(cursor + 32, Endian.little);
    final lfhOffset = bd.getUint32(cursor + 42, Endian.little);
    final cdName = utf8.decode(zip.sublist(cursor + 46, cursor + 46 + nameLen));
    cursor += 46 + nameLen + extraLen + commentLen;

    // Verify matching Local File Header
    expect(bd.getUint32(lfhOffset, Endian.little), 0x04034b50,
        reason: 'Invalid LFH signature at $lfhOffset');
    final lfhFlags = bd.getUint16(lfhOffset + 6, Endian.little);
    final lfhMethod = bd.getUint16(lfhOffset + 8, Endian.little);
    final lfhCrc = bd.getUint32(lfhOffset + 14, Endian.little);
    final lfhCompSize = bd.getUint32(lfhOffset + 18, Endian.little);
    final lfhUncompSize = bd.getUint32(lfhOffset + 22, Endian.little);
    final lfhNameLen = bd.getUint16(lfhOffset + 26, Endian.little);
    final lfhExtraLen = bd.getUint16(lfhOffset + 28, Endian.little);
    final lfhName = utf8.decode(
        zip.sublist(lfhOffset + 30, lfhOffset + 30 + lfhNameLen));

    expect(lfhFlags, cdFlags);
    expect(lfhMethod, cdMethod);
    expect(lfhCrc, cdCrc);
    expect(lfhCompSize, compSize);
    expect(lfhUncompSize, uncompSize);
    expect(lfhName, cdName);

    final dataStart = lfhOffset + 30 + lfhNameLen + lfhExtraLen;
    final data = zip.sublist(dataStart, dataStart + compSize);
    expect(crc32(data), cdCrc);

    out.add(_ParsedZipEntry(
      name: cdName,
      data: data,
      flags: cdFlags,
      method: cdMethod,
      crc: cdCrc,
    ));
  }
  expect(cursor, cdOffset + cdSize);
  return out;
}

void main() {
  group('zip_builder', () {
    test('crc32 matches standard IEEE 802.3 test vectors', () {
      expect(crc32(Uint8List(0)), 0x00000000);
      expect(
        crc32(Uint8List.fromList(utf8.encode('123456789'))),
        0xCBF43926,
      );
    });

    test('builds an empty valid ZIP archive', () {
      final zip = buildZip(const [], timestamp: DateTime(2026, 5, 10, 14, 30));
      final parsed = _parseZip(zip);
      expect(parsed, isEmpty);
      expect(zip.length, 22);
    });

    test('packages multiple files with UTF-8 names and exact payload bytes', () {
      final payload1 = Uint8List.fromList([0x4D, 0x54, 0x68, 0x64, 1, 2, 3]);
      final payload2 = Uint8List.fromList(List.generate(256, (i) => i));

      final zip = buildZip([
        ZipEntry('01 - Sesión Ñ (120 BPM).mid', payload1),
        ZipEntry('02 - Patrón 6-8 (90 BPM).mid', payload2),
      ], timestamp: DateTime(2026, 11, 23, 21, 0, 10));

      final parsed = _parseZip(zip);
      expect(parsed, hasLength(2));

      expect(parsed[0].name, '01 - Sesión Ñ (120 BPM).mid');
      expect(parsed[0].flags, 0x0800);
      expect(parsed[0].method, 0);
      expect(parsed[0].data, payload1);

      expect(parsed[1].name, '02 - Patrón 6-8 (90 BPM).mid');
      expect(parsed[1].flags, 0x0800);
      expect(parsed[1].method, 0);
      expect(parsed[1].data, payload2);
    });
  });
}
