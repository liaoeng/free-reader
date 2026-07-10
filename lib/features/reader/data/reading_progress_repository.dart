import 'package:drift/drift.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/domain/reading_location.dart';

class ReadingProgressRepository {
  const ReadingProgressRepository(this._database);

  static const _currentProgressId = 1;

  final UserDatabase _database;

  Stream<ReadingProgressRecord?> watchLatestProgress() {
    final query = _database.select(_database.readingProgress)
      ..orderBy([
        (progress) => OrderingTerm.desc(progress.lastReadTime),
      ])
      ..limit(1);

    return query.watchSingleOrNull();
  }

  Future<void> saveCurrentLocation(ReadingLocation location) {
    return _database.into(_database.readingProgress).insertOnConflictUpdate(
          ReadingProgressCompanion(
            id: const Value(_currentProgressId),
            volumeSn: Value(location.volumeSn),
            chapterSn: Value(location.chapterSn),
            verseSn: Value(location.verseSn),
            scrollOffset: Value(location.scrollOffset),
            lastReadTime: Value(DateTime.now()),
          ),
        );
  }
}
