import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/core/theme/app_dimens.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/data/resource_reader.dart';
import 'package:free_reader/features/reader/providers/reader_providers.dart';
import 'package:free_reader/features/setting/providers/setting_providers.dart';

class GenericResourceReaderPage extends ConsumerStatefulWidget {
  const GenericResourceReaderPage({
    super.key,
    required this.resourceId,
  });

  final String resourceId;

  @override
  ConsumerState<GenericResourceReaderPage> createState() =>
      _GenericResourceReaderPageState();
}

class _GenericResourceReaderPageState
    extends ConsumerState<GenericResourceReaderPage> {
  final _scrollController = ScrollController();

  ResourceReader? _reader;
  ResourceRecord? _resource;
  List<ResourceCatalogItem> _catalog = const [];
  ResourceContent? _content;
  late Future<void> _loadFuture;
  Timer? _saveProgressTimer;
  bool _restoredOffset = false;
  bool _isSpeaking = false;
  double _pendingRestoreOffset = 0;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadInitialContent();
    _scrollController.addListener(_scheduleProgressSave);
  }

  @override
  void dispose() {
    _saveProgressTimer?.cancel();
    _saveProgressNow();
    ref.read(ttsServiceProvider).stop();
    _reader?.close();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialContent() async {
    final resource = await ref
        .read(resourceRepositoryProvider)
        .getResource(widget.resourceId);
    if (resource == null) {
      throw StateError('Resource not found: ${widget.resourceId}');
    }

    final reader = ref.read(resourceReaderFactoryProvider).create(resource);
    await reader.open();
    final catalog = await reader.getCatalog();
    if (catalog.isEmpty) {
      throw StateError('Resource catalog is empty.');
    }

    final progress = await ref
        .read(readingProgressRepositoryProvider)
        .getProgressForResource(resource.id);
    final progressLocator = progress?.locator;
    final index = progressLocator == null || progressLocator.isEmpty
        ? 0
        : catalog.indexWhere((item) => item.locator == progressLocator);

    _reader = reader;
    _resource = resource;
    _catalog = catalog;
    _selectedIndex = index < 0 ? 0 : index;
    _pendingRestoreOffset = progress?.scrollOffset ?? 0;
    _content = await reader.getContent(_catalog[_selectedIndex].locator);
  }

  Future<void> _openCatalogIndex(int index) async {
    if (index < 0 || index >= _catalog.length) {
      return;
    }

    await _saveProgressNow();
    setState(() {
      _selectedIndex = index;
      _pendingRestoreOffset = 0;
      _restoredOffset = false;
      _loadFuture = _loadContentAt(index);
    });
  }

  Future<void> _loadContentAt(int index) async {
    final reader = _reader;
    if (reader == null) {
      await _loadInitialContent();
      return;
    }
    _content = await reader.getContent(_catalog[index].locator);
    await _saveProgressNow();
  }

  void _restoreOffsetIfNeeded() {
    if (_restoredOffset) {
      return;
    }
    _restoredOffset = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(_pendingRestoreOffset.clamp(0, maxScroll));
    });
  }

  void _scheduleProgressSave() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer(
      const Duration(milliseconds: 500),
      _saveProgressNow,
    );
  }

  Future<void> _saveProgressNow() async {
    final resource = _resource;
    final content = _content;
    if (resource == null || content == null) {
      return;
    }

    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    await ref.read(readingProgressRepositoryProvider).saveGenericProgress(
          resourceId: resource.id,
          locator: content.locator,
          catalogIndex: _selectedIndex,
          scrollOffset: offset,
          progressPercent: _progressPercent(offset),
        );
  }

  double _progressPercent(double offset) {
    if (!_scrollController.hasClients) {
      return 0;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      return 1;
    }
    return (offset / maxScroll).clamp(0.0, 1.0);
  }

  Future<void> _showCatalog() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _GenericCatalogSheet(
        catalog: _catalog,
        selectedIndex: _selectedIndex,
      ),
    );
    if (selected != null) {
      await _openCatalogIndex(selected);
    }
  }

  Future<void> _toggleReadAloud() async {
    final tts = ref.read(ttsServiceProvider);
    if (_isSpeaking) {
      await tts.stop();
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
      return;
    }

    final text = _content?.plainText.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    await _saveProgressNow();
    await tts.speak(text);
    if (mounted) {
      setState(() => _isSpeaking = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(appSettingProvider).valueOrNull;
    final fontSize = setting?.fontSize ?? AppDimens.readerFontSize;

    return Scaffold(
      appBar: AppBar(
        title: Text(_content?.title ?? _resource?.name ?? 'Reader'),
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('读取失败：${snapshot.error}'));
          }

          _restoreOffsetIfNeeded();
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePaddingX,
              AppDimens.pagePaddingY,
              AppDimens.pagePaddingX,
              AppDimens.pagePaddingY + 48,
            ),
            child: SelectableText(
              _content?.plainText ?? '',
              style: TextStyle(
                fontSize: fontSize,
                height: AppDimens.readerLineHeight,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          child: SizedBox(
            height: AppDimens.bottomBarHeight,
            child: Row(
              children: [
                _GenericToolbarButton(
                  icon: Icons.chevron_left,
                  label: '上一篇',
                  onPressed: _selectedIndex > 0
                      ? () => _openCatalogIndex(_selectedIndex - 1)
                      : null,
                ),
                _GenericToolbarButton(
                  icon: Icons.list_alt_outlined,
                  label: '目录',
                  onPressed: _catalog.isEmpty ? null : _showCatalog,
                ),
                _GenericToolbarButton(
                  icon: _isSpeaking
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                  label: _isSpeaking ? '停止' : '朗读',
                  onPressed: _toggleReadAloud,
                ),
                _GenericToolbarButton(
                  icon: Icons.chevron_right,
                  label: '下一篇',
                  onPressed: _selectedIndex < _catalog.length - 1
                      ? () => _openCatalogIndex(_selectedIndex + 1)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenericCatalogSheet extends StatelessWidget {
  const _GenericCatalogSheet({
    required this.catalog,
    required this.selectedIndex,
  });

  final List<ResourceCatalogItem> catalog;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: catalog.length,
        itemBuilder: (context, index) {
          final item = catalog[index];
          final selected = index == selectedIndex;
          return ListTile(
            selected: selected,
            leading: Text('${index + 1}'),
            title: Text(item.title),
            onTap: () => Navigator.of(context).pop(index),
          );
        },
      ),
    );
  }
}

class _GenericToolbarButton extends StatelessWidget {
  const _GenericToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
