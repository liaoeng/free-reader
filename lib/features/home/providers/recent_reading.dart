import 'package:free_reader/database/bible_database.dart';
import 'package:free_reader/database/user_database.dart';

class RecentReading {
  const RecentReading({
    required this.progress,
    required this.book,
  });

  final ReadingProgressRecord progress;
  final BibleBookRecord? book;

  String get title {
    final bookName = book?.fullName ?? '圣经';
    return '$bookName ${progress.chapterSn}:${progress.verseSn}';
  }
}
