import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/features/reader/data/bible_sqlite_reader.dart';
import 'package:free_reader/features/home/providers/recent_reading.dart';
import 'package:free_reader/features/reader/providers/reader_providers.dart';

final recentReadingProvider = StreamProvider<RecentReading?>((ref) async* {
  final progressRepository = ref.watch(readingProgressRepositoryProvider);
  final resourceRepository = ref.watch(resourceRepositoryProvider);
  final readerFactory = ref.watch(resourceReaderFactoryProvider);

  await for (final progress in progressRepository.watchLatestProgress()) {
    if (progress == null) {
      yield null;
      continue;
    }

    final resource = await resourceRepository.getResource(progress.resourceId);
    if (resource == null) {
      yield null;
      continue;
    }

    String? bookName;
    final reader = readerFactory.create(resource);
    if (reader is BibleSqliteReader) {
      await reader.open();
      try {
        final book = await reader.getBook(progress.volumeSn);
        bookName = book?.fullName ?? book?.shortName;
      } finally {
        await reader.close();
      }
    }
    yield RecentReading(
      progress: progress,
      resource: resource,
      bookName: bookName,
    );
  }
});
