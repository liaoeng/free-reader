import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:free_reader/database/connections/database_paths.dart';

LazyDatabase openBibleConnection() {
  return LazyDatabase(() async {
    final dbFile = await DatabasePaths.bibleDatabaseFile();

    if (!await dbFile.exists()) {
      await dbFile.parent.create(recursive: true);
      final assetBytes = await rootBundle.load(DatabasePaths.bibleAssetPath);
      await dbFile.writeAsBytes(
        assetBytes.buffer.asUint8List(),
        flush: true,
      );
    }

    return NativeDatabase(dbFile, readOnly: true);
  });
}
