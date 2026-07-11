import 'package:free_reader/database/user_database.dart';

class RecentReading {
  const RecentReading({
    required this.progress,
    required this.resource,
    this.bookName,
  });

  final ReadingProgressRecord progress;
  final ResourceRecord resource;
  final String? bookName;

  String get title {
    final prefix = bookName ?? resource.name;
    return '$prefix ${progress.chapterSn}:${progress.verseSn}';
  }
}
