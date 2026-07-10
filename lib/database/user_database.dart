import 'package:drift/drift.dart';
import 'package:free_reader/database/connections/user_connection.dart';
import 'package:free_reader/database/tables/user_tables.dart';

part 'user_database.g.dart';

@DriftDatabase(tables: [ReadingProgress, AppSettings])
class UserDatabase extends _$UserDatabase {
  UserDatabase() : super(openUserConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (migrator, from, to) async {
        // Keep this branch explicit so future user-data tables can migrate
        // without touching the read-only Bible database.
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
