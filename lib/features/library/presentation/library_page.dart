import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/presentation/reader_page.dart';
import 'package:free_reader/features/reader/providers/reader_providers.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String? _exportingResourceId;

  @override
  Widget build(BuildContext context) {
    final resources = ref.watch(resourcesProvider);
    final exportRecords = ref.watch(exportRecordsProvider);

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
              resources.when(
                data: (value) {
                  if (value.isEmpty) {
                    return const _LibraryEmptyTile();
                  }
                  return Column(
                    children: [
                      for (final resource in value) ...[
                        _ResourceTile(
                          resource: resource,
                          exporting: _exportingResourceId == resource.id,
                          onOpen: () => _openResource(resource),
                          onExport: () => _exportResource(resource),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
                loading: () => const _LibraryLoadingTile(),
                error: (error, stackTrace) =>
                    _LibraryErrorTile(message: '$error'),
              ),
              const SizedBox(height: 12),
              Text(
                '导出记录',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              exportRecords.when(
                data: (records) => _ExportRecordList(
                  records: records,
                  onOpenDirectory: _openDirectory,
                ),
                loading: () => const _ExportRecordLoadingTile(),
                error: (error, stackTrace) =>
                    _LibraryErrorTile(message: '$error'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openResource(ResourceRecord resource) async {
    final progress = await ref
        .read(readingProgressRepositoryProvider)
        .getProgressForResource(resource.id);
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          resourceId: resource.id,
          initialVolumeSn: progress?.volumeSn ?? 1,
          initialChapterSn: progress?.chapterSn ?? 1,
          initialVerseSn: progress?.verseSn ?? 1,
          initialScrollOffset: progress?.scrollOffset ?? 0,
        ),
      ),
    );
  }

  Future<void> _exportResource(ResourceRecord resource) async {
    if (_exportingResourceId != null) {
      return;
    }

    setState(() => _exportingResourceId = resource.id);
    try {
      final record = await ref
          .read(resourceExportServiceProvider)
          .exportResource(resource);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出：${record.filePath}'),
          action: SnackBarAction(
            label: '打开目录',
            onPressed: () => _openDirectory(record.directoryPath),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingResourceId = null);
      }
    }
  }

  Future<void> _openDirectory(String path) async {
    final opened =
        await ref.read(pathLauncherServiceProvider).openDirectory(path);
    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('无法自动打开目录：$path')),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.resource,
    required this.exporting,
    required this.onOpen,
    required this.onExport,
  });

  final ResourceRecord resource;
  final bool exporting;
  final VoidCallback onOpen;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(resource.resourceType)),
        title: Text(resource.name),
        subtitle: Text(
          '${resource.resourceType} · ${resource.fileFormat} · ${_formatSize(resource.fileSize)}',
        ),
        trailing: exporting
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<_ResourceAction>(
                onSelected: (action) {
                  switch (action) {
                    case _ResourceAction.export:
                      onExport();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ResourceAction.export,
                    child: ListTile(
                      leading: Icon(Icons.ios_share_outlined),
                      title: Text('导出这本书'),
                    ),
                  ),
                ],
              ),
        onTap: onOpen,
        onLongPress: onExport,
      ),
    );
  }

  IconData _iconFor(String resourceType) {
    return switch (resourceType) {
      'BIBLE' => Icons.menu_book_outlined,
      'HYMN' => Icons.library_music_outlined,
      'PDF' => Icons.picture_as_pdf_outlined,
      'TXT' || 'MARKDOWN' => Icons.article_outlined,
      _ => Icons.auto_stories_outlined,
    };
  }

  String _formatSize(int size) {
    if (size < 1024) {
      return '$size B';
    }
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _ExportRecordList extends StatelessWidget {
  const _ExportRecordList({
    required this.records,
    required this.onOpenDirectory,
  });

  final List<ExportRecord> records;
  final ValueChanged<String> onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.inventory_2_outlined),
          title: Text('暂无导出记录'),
          subtitle: Text('长按书架中的资源即可导出单本资源'),
        ),
      );
    }

    return Column(
      children: [
        for (final record in records) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(record.resourceName),
              subtitle: Text(
                '${_formatTime(record.createdAt)}\n${record.filePath}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => onOpenDirectory(record.directoryPath),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class _LibraryEmptyTile extends StatelessWidget {
  const _LibraryEmptyTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.auto_stories_outlined),
        title: Text('暂无资源'),
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
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在读取资源'),
      ),
    );
  }
}

class _ExportRecordLoadingTile extends StatelessWidget {
  const _ExportRecordLoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在读取导出记录'),
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

enum _ResourceAction { export }
