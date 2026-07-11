import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/features/home/providers/home_providers.dart';
import 'package:free_reader/features/home/providers/recent_reading.dart';
import 'package:free_reader/features/reader/presentation/reader_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentReading = ref.watch(recentReadingProvider);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('Free Reader'),
          floating: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              Text(
                '最近阅读',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              recentReading.when(
                data: (value) => _RecentReadingCard(recentReading: value),
                loading: () => const _LoadingCard(),
                error: (error, stackTrace) => _ErrorCard(message: '$error'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentReadingCard extends StatelessWidget {
  const _RecentReadingCard({required this.recentReading});

  final RecentReading? recentReading;

  @override
  Widget build(BuildContext context) {
    final value = recentReading;

    if (value == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.auto_stories_outlined),
          title: Text('暂无阅读记录'),
          subtitle: Text('从书架打开圣经后会自动保存进度'),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(value.title),
        subtitle: Text('上次阅读 ${_formatReadTime(value.progress.lastReadTime)}'),
        trailing: FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReaderPage(
                  resourceId: value.progress.resourceId,
                  initialVolumeSn: value.progress.volumeSn,
                  initialChapterSn: value.progress.chapterSn,
                  initialVerseSn: value.progress.verseSn,
                  initialScrollOffset: value.progress.scrollOffset,
                ),
              ),
            );
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('继续'),
        ),
      ),
    );
  }

  static String _formatReadTime(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在读取'),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

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
