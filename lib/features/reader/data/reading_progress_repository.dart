import 'package:drift/drift.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/domain/reading_location.dart';

class ReadingProgressRepository {
  const ReadingProgressRepository(this._database);

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
    return saveProgress(
      resourceId: location.resourceId,
      locator: location.locator,
      volumeSn: location.volumeSn,
      chapterSn: location.chapterSn,
      verseSn: location.verseSn,
      scrollOffset: location.scrollOffset,
      progressPercent: location.progressPercent,
    );
  }

  Future<ReadingProgressRecord?> getProgressForResource(String resourceId) {
    final query = _database.select(_database.readingProgress)
      ..where((progress) => progress.resourceId.equals(resourceId))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> saveProgress({
    required String resourceId,
    required String locator,
    required int volumeSn,
    required int chapterSn,
    required int verseSn,
    double scrollOffset = 0,
    double progressPercent = 0,
  }) async {
    final now = DateTime.now();
    final existing = await getProgressForResource(resourceId);
    final companion = ReadingProgressCompanion(
      id: existing == null ? const Value.absent() : Value(existing.id),
      resourceId: Value(resourceId),
      locator: Value(locator),
      volumeSn: Value(volumeSn),
      chapterSn: Value(chapterSn),
      verseSn: Value(verseSn),
      chapter: Value(chapterSn),
      scrollOffset: Value(scrollOffset),
      progressPercent: Value(progressPercent),
      lastReadTime: Value(now),
    );

    await _database.into(_database.readingProgress).insertOnConflictUpdate(
          companion,
        );
  }
}
