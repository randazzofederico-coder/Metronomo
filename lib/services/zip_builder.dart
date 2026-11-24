import 'dart:convert';
import 'dart:typed_data';

/// Single file entry to store inside a ZIP archive.
class ZipEntry {
  final String name;
  final Uint8List data;

  const ZipEntry(this.name, this.data);
}

/// Builds an uncompressed (STORE) PKZIP archive in memory with UTF-8 filenames.
///
/// Designed for packaging small binary exports (such as `.mid` files) without
/// adding third-party archive dependencies.
Uint8List buildZip(List<ZipEntry> entries, {DateTime? timestamp}) {
  final dt = timestamp ?? DateTime.now();
  final dosTime = _encodeDosTime(dt);
  final dosDate = _encodeDosDate(dt);

  final body = BytesBuilder(copy: false);
  final centralDirectory = BytesBuilder(copy: false);
  var offset = 0;

  for (final entry in entries) {
    final nameBytes = utf8.encode(entry.name);
    final crc = crc32(entry.data);
    final size = entry.data.length;

    // Local File Header (30 bytes + filename)
    final lfh = ByteData(30);
    lfh.setUint32(0, 0x04034b50, Endian.little);
    lfh.setUint16(4, 20, Endian.little); // Version needed: 2.0
    lfh.setUint16(6, 0x0800, Endian.little); // UTF-8 filename flag
    lfh.setUint16(8, 0, Endian.little); // Method 0 = STORE
    lfh.setUint16(10, dosTime, Endian.little);
    lfh.setUint16(12, dosDate, Endian.little);
    lfh.setUint32(14, crc, Endian.little);
    lfh.setUint32(18, size, Endian.little);
    lfh.setUint32(22, size, Endian.little);
    lfh.setUint16(26, nameBytes.length, Endian.little);
    lfh.setUint16(28, 0, Endian.little); // Extra field length

    body.add(lfh.buffer.asUint8List());
    body.add(nameBytes);
    body.add(entry.data);

    // Central Directory File Header (46 bytes + filename)
    final cdh = ByteData(46);
    cdh.setUint32(0, 0x02014b50, Endian.little);
    cdh.setUint16(4, 20, Endian.little); // Version made by
    cdh.setUint16(6, 20, Endian.little); // Version needed: 2.0
    cdh.setUint16(8, 0x0800, Endian.little); // UTF-8 filename flag
    cdh.setUint16(10, 0, Endian.little); // Method 0 = STORE
    cdh.setUint16(12, dosTime, Endian.little);
    cdh.setUint16(14, dosDate, Endian.little);
    cdh.setUint32(16, crc, Endian.little);
    cdh.setUint32(20, size, Endian.little);
    cdh.setUint32(24, size, Endian.little);
    cdh.setUint16(28, nameBytes.length, Endian.little);
    cdh.setUint16(30, 0, Endian.little); // Extra field length
    cdh.setUint16(32, 0, Endian.little); // File comment length
    cdh.setUint16(34, 0, Endian.little); // Disk number start
    cdh.setUint16(36, 0, Endian.little); // Internal file attributes
    cdh.setUint32(38, 0, Endian.little); // External file attributes
    cdh.setUint32(42, offset, Endian.little);

    centralDirectory.add(cdh.buffer.asUint8List());
    centralDirectory.add(nameBytes);

    offset += 30 + nameBytes.length + size;
  }

  final cdBytes = centralDirectory.takeBytes();

  // End of Central Directory Record (22 bytes)
  final eocd = ByteData(22);
  eocd.setUint32(0, 0x06054b50, Endian.little);
  eocd.setUint16(4, 0, Endian.little); // Number of this disk
  eocd.setUint16(6, 0, Endian.little); // Disk where CD starts
  eocd.setUint16(8, entries.length, Endian.little);
  eocd.setUint16(10, entries.length, Endian.little);
  eocd.setUint32(12, cdBytes.length, Endian.little);
  eocd.setUint32(16, offset, Endian.little);
  eocd.setUint16(20, 0, Endian.little); // Comment length

  final result = BytesBuilder(copy: false);
  result.add(body.takeBytes());
  result.add(cdBytes);
  result.add(eocd.buffer.asUint8List());
  return result.takeBytes();
}

int _encodeDosTime(DateTime dt) {
  final hour = dt.hour.clamp(0, 23);
  final minute = dt.minute.clamp(0, 59);
  final secondHalf = (dt.second.clamp(0, 59)) >> 1;
  return (hour << 11) | (minute << 5) | secondHalf;
}

int _encodeDosDate(DateTime dt) {
  final year = dt.year.clamp(1980, 2107);
  final month = dt.month.clamp(1, 12);
  final day = dt.day.clamp(1, 31);
  return ((year - 1980) << 9) | (month << 5) | day;
}

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var i = 0; i < 256; i++) {
    var c = i;
    for (var j = 0; j < 8; j++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c;
  }
  return table;
}

/// Computes IEEE 802.3 CRC-32 for [bytes].
int crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (var i = 0; i < bytes.length; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
