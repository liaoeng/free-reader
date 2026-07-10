import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:free_reader/database/connections/database_paths.dart';

LazyDatabase openUserConnection() {
  return LazyDatabase(() async {
    final dbFile = await DatabasePaths.userDatabaseFile();
    await dbFile.parent.create(recursive: true);
    return NativeDatabase(dbFile);
  });
}
