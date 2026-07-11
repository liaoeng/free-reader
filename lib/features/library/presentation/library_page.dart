import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/bible_database.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/library/providers/library_providers.dart';
import 'package:free_reader/features/reader/presentation/reader_page.dart';
import 'package:free_reader/features/reader/providers/reader_providers.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bibleBooksProvider);
    final progress = ref.watch(latestReadingProgressProvider).valueOrNull;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('书架'),
          floating: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              books.when(
                data: (value) => _BibleTile(
                  books: value,
                  progress: progress,
                ),
                loading: () => const _LibraryLoadingTile(),
                error: (error, stackTrace) =>
                    _LibraryErrorTile(message: '$error'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BibleTile extends StatelessWidget {
  const _BibleTile({
    required this.books,
    required this.progress,
  });

  final List<BibleBookRecord> books;
  final ReadingProgressRecord? progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book),
        title: const Text('圣经'),
        subtitle: Text('简体中文和合本 · ${books.length} 卷'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReaderPage(
                initialVolumeSn: progress?.volumeSn ?? 1,
                initialChapterSn: progress?.chapterSn ?? 1,
                initialVerseSn: progress?.verseSn ?? 1,
                initialScrollOffset: progress?.scrollOffset ?? 0,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LibraryLoadingTile extends StatelessWidget {
  const _LibraryLoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在读取圣经'),
      ),
    );
  }
}

class _LibraryErrorTile extends StatelessWidget {
  const _LibraryErrorTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('读取失败'),
        subtitle: Text(message),
      ),
    );
  }
}
