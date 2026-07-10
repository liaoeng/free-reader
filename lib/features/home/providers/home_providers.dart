import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/features/home/providers/recent_reading.dart';
import 'package:free_reader/features/reader/providers/reader_providers.dart';

final recentReadingProvider = StreamProvider<RecentReading?>((ref) async* {
  final progressRepository = ref.watch(readingProgressRepositoryProvider);
  final bibleRepository = ref.watch(bibleRepositoryProvider);

  await for (final progress in progressRepository.watchLatestProgress()) {
    if (progress == null) {
      yield null;
      continue;
    }

    final book = await bibleRepository.getBook(progress.volumeSn);
    yield RecentReading(progress: progress, book: book);
  }
});
