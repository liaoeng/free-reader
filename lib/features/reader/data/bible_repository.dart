import 'package:drift/drift.dart';
import 'package:free_reader/database/bible_database.dart';

class BibleRepository {
  const BibleRepository(this._database);

  final BibleDatabase _database;

  Future<List<BibleBookRecord>> watchableBooksSnapshot() {
    final query = _database.select(_database.bibleBooks)
      ..orderBy([(book) => OrderingTerm.asc(book.sn)]);
    return query.get();
  }

  Stream<List<BibleBookRecord>> watchBooks() {
    final query = _database.select(_database.bibleBooks)
      ..orderBy([(book) => OrderingTerm.asc(book.sn)]);
    return query.watch();
  }

  Future<BibleBookRecord?> getBook(int volumeSn) {
    final query = _database.select(_database.bibleBooks)
      ..where((book) => book.sn.equals(volumeSn))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<List<BibleVerseRecord>> getChapter({
    required int volumeSn,
    required int chapterSn,
  }) {
    final query = _database.select(_database.bibleVerses)
      ..where(
        (verse) =>
            verse.volumeSn.equals(volumeSn) & verse.chapterSn.equals(chapterSn),
      )
      ..orderBy([
        (verse) => OrderingTerm.asc(verse.verseSn),
      ]);

    return query.get();
  }
}
