import 'dart:convert';
import 'dart:typed_data';

class SimpleZipWriter {
  SimpleZipWriter();

  final _entries = <_ZipEntry>[];

  void addFile(String path, List<int> bytes) {
    final normalizedPath = path.replaceAll('\\', '/');
    final data = Uint8List.fromList(bytes);
    _entries.add(
      _ZipEntry(
        path: normalizedPath,
        data: data,
        crc32: _crc32(data),
        modified: DateTime.now(),
      ),
    );
  }

  Uint8List build() {
    final output = BytesBuilder(copy: false);
    final centralDirectory = BytesBuilder(copy: false);
    var offset = 0;

    for (final entry in _entries) {
      final nameBytes = utf8.encode(entry.path);
      final dosTime = _dosTime(entry.modified);
      final dosDate = _dosDate(entry.modified);

      final localHeader = BytesBuilder(copy: false)
        ..add(_uint32(0x04034b50))
        ..add(_uint16(20))
        ..add(_uint16(0x0800))
        ..add(_uint16(0))
        ..add(_uint16(dosTime))
        ..add(_uint16(dosDate))
        ..add(_uint32(entry.crc32))
        ..add(_uint32(entry.data.length))
        ..add(_uint32(entry.data.length))
        ..add(_uint16(nameBytes.length))
        ..add(_uint16(0))
        ..add(nameBytes);

      final localHeaderBytes = localHeader.takeBytes();
      output
        ..add(localHeaderBytes)
        ..add(entry.data);

      centralDirectory
        ..add(_uint32(0x02014b50))
        ..add(_uint16(20))
        ..add(_uint16(20))
        ..add(_uint16(0x0800))
        ..add(_uint16(0))
        ..add(_uint16(dosTime))
        ..add(_uint16(dosDate))
        ..add(_uint32(entry.crc32))
        ..add(_uint32(entry.data.length))
        ..add(_uint32(entry.data.length))
        ..add(_uint16(nameBytes.length))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint32(0))
        ..add(_uint32(offset))
        ..add(nameBytes);

      offset += localHeaderBytes.length + entry.data.length;
    }

    final centralDirectoryBytes = centralDirectory.takeBytes();
    output
      ..add(centralDirectoryBytes)
      ..add(_uint32(0x06054b50))
      ..add(_uint16(0))
      ..add(_uint16(0))
      ..add(_uint16(_entries.length))
      ..add(_uint16(_entries.length))
      ..add(_uint32(centralDirectoryBytes.length))
      ..add(_uint32(offset))
      ..add(_uint16(0));

    return output.takeBytes();
  }

  static List<int> _uint16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  static List<int> _uint32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  static int _dosTime(DateTime dateTime) {
    return (dateTime.hour << 11) |
        (dateTime.minute << 5) |
        (dateTime.second ~/ 2);
  }

  static int _dosDate(DateTime dateTime) {
    final year = dateTime.year < 1980 ? 0 : dateTime.year - 1980;
    return (year << 9) | (dateTime.month << 5) | dateTime.day;
  }

  static int _crc32(Uint8List bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  static final List<int> _crcTable = List<int>.generate(256, (index) {
    var crc = index;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
    }
    return crc;
  });
}

class _ZipEntry {
  const _ZipEntry({
    required this.path,
    required this.data,
    required this.crc32,
    required this.modified,
  });

  final String path;
  final Uint8List data;
  final int crc32;
  final DateTime modified;
}
