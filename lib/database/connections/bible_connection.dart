import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:free_reader/database/connections/database_paths.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

LazyDatabase openBibleConnection({String? filePath}) {
  return LazyDatabase(() async {
    final dbFile = filePath == null
        ? await DatabasePaths.builtinBibleResourceFile()
        : await DatabasePaths.fileForResourcePath(filePath);

    if (!await dbFile.exists()) {
      await dbFile.parent.create(recursive: true);
      final legacyFile = await DatabasePaths.bibleDatabaseFile();
      if (await legacyFile.exists()) {
        await legacyFile.copy(dbFile.path);
      } else {
        final assetBytes = await rootBundle.load(DatabasePaths.bibleAssetPath);
        await dbFile.writeAsBytes(
          assetBytes.buffer.asUint8List(),
          flush: true,
        );
      }
    }

    if (!await dbFile.exists()) {
      final assetBytes = await rootBundle.load(DatabasePaths.bibleAssetPath);
      await dbFile.writeAsBytes(
        assetBytes.buffer.asUint8List(),
        flush: true,
      );
    }

    final database = sqlite.sqlite3.open(
      dbFile.path,
      mode: sqlite.OpenMode.readOnly,
    );

    return NativeDatabase.opened(database, enableMigrations: false);
  });
}
