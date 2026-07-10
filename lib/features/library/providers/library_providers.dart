import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/bible_database.dart';
import 'package:free_reader/features/reader/providers/reader_providers.dart';

final bibleBooksProvider = StreamProvider<List<BibleBookRecord>>((ref) {
  return ref.watch(bibleRepositoryProvider).watchBooks();
});
