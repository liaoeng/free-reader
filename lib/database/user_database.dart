import 'package:drift/drift.dart';
import 'package:free_reader/database/connections/user_connection.dart';
import 'package:free_reader/database/tables/user_tables.dart';

part 'user_database.g.dart';

@DriftDatabase(
  tables: [
    Resources,
    ReadingProgress,
    Bookmarks,
    Favorites,
    Highlights,
    ExportRecords,
    AppSettings,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase() : super(openUserConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(resources);
          await migrator.createTable(bookmarks);
          await migrator.createTable(favorites);
          await migrator.createTable(highlights);
          await migrator.createTable(exportRecords);
          await migrator.addColumn(readingProgress, readingProgress.resourceId);
          await migrator.addColumn(readingProgress, readingProgress.locator);
          await migrator.addColumn(readingProgress, readingProgress.chapter);
          await migrator.addColumn(readingProgress, readingProgress.page);
          await migrator.addColumn(
            readingProgress,
            readingProgress.progressPercent,
          );
          await customStatement(
            'UPDATE reading_progress SET locator = '
            "'bible:' || volume_sn || ':' || chapter_sn || ':' || verse_sn, "
            'chapter = chapter_sn WHERE locator = \'\'',
          );
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
