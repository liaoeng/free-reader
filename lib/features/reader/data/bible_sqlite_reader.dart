import 'package:free_reader/database/bible_database.dart';
import 'package:free_reader/features/reader/data/bible_repository.dart';
import 'package:free_reader/features/reader/data/resource_reader.dart';

class BibleSqliteReader extends ResourceReader {
  BibleSqliteReader(super.resource);

  late final BibleDatabase _database;
  late final BibleRepository _repository;
  bool _opened = false;

  @override
  Future<void> open() async {
    if (_opened) {
      return;
    }
    _database = BibleDatabase(filePath: resource.filePath);
    _repository = BibleRepository(_database);
    _opened = true;
  }

  Future<List<BibleBookRecord>> getBooksSnapshot() async {
    await open();
    return _repository.watchableBooksSnapshot();
  }

  Future<BibleBookRecord?> getBook(int volumeSn) async {
    await open();
    return _repository.getBook(volumeSn);
  }

  Future<List<BibleVerseRecord>> getChapter({
    required int volumeSn,
    required int chapterSn,
  }) async {
    await open();
    return _repository.getChapter(volumeSn: volumeSn, chapterSn: chapterSn);
  }

  @override
  Future<ResourceMetadata> getMetadata() async {
    return ResourceMetadata(
      title: resource.name,
      language: resource.language,
      author: resource.author,
    );
  }

  @override
  Future<List<ResourceCatalogItem>> getCatalog() async {
    final books = await getBooksSnapshot();
    return [
      for (final book in books)
        ResourceCatalogItem(
          locator: 'bible:${book.sn}:1:1',
          title: book.fullName ?? book.shortName ?? '${book.sn}',
          children: [
            for (var chapter = 1;
                chapter <= (book.chapterNumber ?? 1);
                chapter++)
              ResourceCatalogItem(
                locator: 'bible:${book.sn}:$chapter:1',
                title: '$chapter',
              ),
          ],
        ),
    ];
  }

  @override
  Future<ResourceContent> getContent(String locator) async {
    final parts = locator.split(':');
    final volumeSn = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    final chapterSn = parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1;
    final book = await getBook(volumeSn);
    final verses = await getChapter(volumeSn: volumeSn, chapterSn: chapterSn);
    final title =
        '${book?.fullName ?? book?.shortName ?? resource.name} $chapterSn';
    return ResourceContent(
      locator: 'bible:$volumeSn:$chapterSn:1',
      title: title,
      plainText: verses.map((verse) => verse.lection ?? '').join('\n'),
    );
  }

  @override
  Future<List<ResourceContent>> search(String keyword) async {
    return const [];
  }

  @override
  Future<void> close() async {
    if (!_opened) {
      return;
    }
    await _database.close();
    _opened = false;
  }
}
