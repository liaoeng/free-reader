import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/database_providers.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/data/bible_repository.dart';
import 'package:free_reader/features/reader/data/reading_progress_repository.dart';

final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  return BibleRepository(ref.watch(bibleDatabaseProvider));
});

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository(ref.watch(userDatabaseProvider));
});

final latestReadingProgressProvider =
    StreamProvider<ReadingProgressRecord?>((ref) {
  return ref.watch(readingProgressRepositoryProvider).watchLatestProgress();
});
