import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/core/theme/app_dimens.dart';
import 'package:free_reader/database/bible_database.dart';
import 'package:free_reader/features/reader/data/bible_sqlite_reader.dart';
import 'package:free_reader/features/reader/data/tts_service.dart';
import 'package:free_reader/features/reader/domain/reading_location.dart';
import 'package:free_reader/features/reader/providers/reader_providers.dart';
import 'package:free_reader/features/resources/domain/resource_constants.dart';
import 'package:free_reader/features/setting/providers/setting_providers.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    this.resourceId = ResourceConstants.builtinBibleId,
    this.initialVolumeSn = 1,
    this.initialChapterSn = 1,
    this.initialVerseSn = 1,
    this.initialScrollOffset = 0,
  });

  final String resourceId;
  final int initialVolumeSn;
  final int initialChapterSn;
  final int initialVerseSn;
  final double initialScrollOffset;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _scrollController = ScrollController();

  late int _volumeSn;
  late int _chapterSn;
  late int _verseSn;
  late double _pendingRestoreOffset;
  late Future<_ReaderChapter> _chapter;

  List<BibleVerseRecord> _currentVerses = const [];
  final Map<int, GlobalKey> _verseKeys = {};
  Timer? _saveProgressTimer;
  bool _restoredInitialOffset = false;
  bool _ignoreScrollUntilNextFrame = false;
  bool _showControls = false;
  bool _isSpeaking = false;
  int _chapterDirection = 1;

  @override
  void initState() {
    super.initState();
    _volumeSn = widget.initialVolumeSn;
    _chapterSn = widget.initialChapterSn;
    _verseSn = widget.initialVerseSn;
    _pendingRestoreOffset = widget.initialScrollOffset;
    _chapter = _loadChapter(saveInitialProgress: false);
    _scrollController.addListener(_scheduleProgressSave);
    ref.read(ttsServiceProvider).setProgressListener(_handleTtsProgress);
  }

  @override
  void dispose() {
    _saveProgressTimer?.cancel();
    _saveProgressNow();
    final tts = ref.read(ttsServiceProvider);
    tts.setProgressListener(null);
    tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ReaderChapter> _loadChapter({bool saveInitialProgress = true}) async {
    final resource = await ref
        .read(resourceRepositoryProvider)
        .getResource(widget.resourceId);
    if (resource == null) {
      throw StateError('Resource not found: ${widget.resourceId}');
    }

    final reader = ref.read(resourceReaderFactoryProvider).create(resource);
    if (reader is! BibleSqliteReader) {
      throw UnsupportedError('Reader page only supports Bible resources now.');
    }

    await reader.open();
    late final List<BibleBookRecord> books;
    late final BibleBookRecord? book;
    late final List<BibleVerseRecord> verses;
    try {
      books = await reader.getBooksSnapshot();
      book = await reader.getBook(_volumeSn);
      verses = await reader.getChapter(
        volumeSn: _volumeSn,
        chapterSn: _chapterSn,
      );
    } finally {
      await reader.close();
    }

    _currentVerses = verses;
    _verseKeys
      ..clear()
      ..addEntries(
        verses.map((verse) => MapEntry(verse.verseSn, GlobalKey())),
      );

    if (saveInitialProgress && verses.isNotEmpty) {
      await ref.read(readingProgressRepositoryProvider).saveCurrentLocation(
            ReadingLocation(
              resourceId: widget.resourceId,
              volumeSn: _volumeSn,
              chapterSn: _chapterSn,
              verseSn: verses.first.verseSn,
            ),
          );
    }

    return _ReaderChapter(
      books: books,
      book: book,
      chapterSn: _chapterSn,
      verses: verses,
    );
  }

  void _restorePositionIfNeeded() {
    if (_restoredInitialOffset) {
      return;
    }

    _restoredInitialOffset = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _ignoreScrollUntilNextFrame = true;
      final verseContext = _verseKeys[_verseSn]?.currentContext;
      if (verseContext != null) {
        Scrollable.ensureVisible(
          verseContext,
          alignment: 0.45,
          duration: Duration.zero,
        );
      } else if (_pendingRestoreOffset > 0) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(_pendingRestoreOffset.clamp(0, maxScroll));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ignoreScrollUntilNextFrame = false;
      });
    });
  }

  void _openChapter(
    int volumeSn,
    int chapterSn, {
    int verseSn = 1,
    double scrollOffset = 0,
    int direction = 0,
  }) {
    _saveProgressTimer?.cancel();
    _saveProgressNow();
    if (_isSpeaking) {
      ref.read(ttsServiceProvider).stop();
    }

    setState(() {
      _volumeSn = volumeSn;
      _chapterSn = chapterSn;
      _verseSn = verseSn;
      _pendingRestoreOffset = scrollOffset;
      _restoredInitialOffset = false;
      _showControls = false;
      _isSpeaking = false;
      _chapterDirection = direction == 0 ? 1 : direction;
      _chapter = _loadChapter();
    });

    if (_scrollController.hasClients) {
      _ignoreScrollUntilNextFrame = true;
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ignoreScrollUntilNextFrame = false;
      });
    }
  }

  void _openPreviousChapter(_ReaderChapter chapter) {
    final book = chapter.book;
    if (book == null) {
      return;
    }

    if (_chapterSn > 1) {
      _openChapter(_volumeSn, _chapterSn - 1, direction: -1);
      return;
    }

    final index =
        chapter.books.indexWhere((candidate) => candidate.sn == book.sn);
    if (index <= 0) {
      return;
    }

    final previousBook = chapter.books[index - 1];
    _openChapter(
      previousBook.sn,
      previousBook.chapterNumber ?? 1,
      direction: -1,
    );
  }

  void _openNextChapter(_ReaderChapter chapter) {
    final book = chapter.book;
    if (book == null) {
      return;
    }

    final chapterCount = book.chapterNumber ?? _chapterSn;
    if (_chapterSn < chapterCount) {
      _openChapter(_volumeSn, _chapterSn + 1, direction: 1);
      return;
    }

    final index =
        chapter.books.indexWhere((candidate) => candidate.sn == book.sn);
    if (index < 0 || index >= chapter.books.length - 1) {
      return;
    }

    _openChapter(chapter.books[index + 1].sn, 1, direction: 1);
  }

  void _scheduleProgressSave() {
    if (_ignoreScrollUntilNextFrame || !_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.extentAfter < 48 && !_showControls) {
      setState(() => _showControls = true);
    }

    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer(
      const Duration(milliseconds: 500),
      _saveProgressNow,
    );
  }

  Future<void> _saveProgressNow() async {
    if (!mounted) {
      return;
    }

    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    _verseSn = _findVerseNearViewportCenter() ?? _estimateVisibleVerse(offset);

    await ref.read(readingProgressRepositoryProvider).saveCurrentLocation(
          ReadingLocation(
            resourceId: widget.resourceId,
            volumeSn: _volumeSn,
            chapterSn: _chapterSn,
            verseSn: _verseSn,
            scrollOffset: offset,
            progressPercent: _chapterProgress(offset),
          ),
        );
  }

  double _chapterProgress(double offset) {
    if (!_scrollController.hasClients) {
      return 0;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      return 1;
    }
    return (offset / maxScroll).clamp(0.0, 1.0);
  }

  int? _findVerseNearViewportCenter() {
    if (_currentVerses.isEmpty) {
      return null;
    }

    final viewportCenter = MediaQuery.sizeOf(context).height / 2;
    int? bestVerseSn;
    double? bestDistance;

    for (final verse in _currentVerses) {
      final verseContext = _verseKeys[verse.verseSn]?.currentContext;
      if (verseContext == null) {
        continue;
      }

      final renderObject = verseContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final top = renderObject.localToGlobal(Offset.zero).dy;
      final center = top + renderObject.size.height / 2;
      final distance = (center - viewportCenter).abs();

      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestVerseSn = verse.verseSn;
      }
    }

    return bestVerseSn;
  }

  int _estimateVisibleVerse(double offset) {
    if (_currentVerses.isEmpty || !_scrollController.hasClients) {
      return _verseSn;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      return _currentVerses.first.verseSn;
    }

    final progress = (offset / maxScroll).clamp(0.0, 1.0);
    final index = (progress * (_currentVerses.length - 1)).floor();
    return _currentVerses[index].verseSn;
  }

  Future<void> _showIndex(_ReaderChapter chapter) async {
    final selected = await showModalBottomSheet<_ChapterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _BibleIndexSheet(
          books: chapter.books,
          selectedVolumeSn: _volumeSn,
          selectedChapterSn: _chapterSn,
        );
      },
    );

    if (selected == null) {
      return;
    }

    _openChapter(selected.volumeSn, selected.chapterSn);
  }

  Future<void> _showTextSettings() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ReaderTextSettingsSheet(),
    );
  }

  Future<void> _toggleReadAloud(_ReaderChapter chapter) async {
    final tts = ref.read(ttsServiceProvider);

    if (_isSpeaking) {
      await tts.stop();
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
      return;
    }

    final startVerseSn = _findVerseNearViewportCenter() ??
        _estimateVisibleVerse(
          _scrollController.hasClients ? _scrollController.offset : 0,
        );
    _verseSn = startVerseSn;
    await _saveProgressNow();

    final segments = [
      for (final verse in chapter.verses)
        if (verse.verseSn >= startVerseSn)
          TtsSegment(
            id: '$_volumeSn:$_chapterSn:${verse.verseSn}',
            text: verse.lection ?? '',
          ),
    ].where((segment) => segment.text.trim().isNotEmpty).toList();
    if (segments.isEmpty) {
      return;
    }

    await tts.speakSegments(segments);
    if (mounted) {
      setState(() => _isSpeaking = true);
    }
  }

  void _handleTtsProgress(TtsProgress progress) {
    final parts = progress.segmentId.split(':');
    if (parts.length != 3) {
      return;
    }

    final volumeSn = int.tryParse(parts[0]);
    final chapterSn = int.tryParse(parts[1]);
    final verseSn = int.tryParse(parts[2]);
    if (volumeSn == null || chapterSn == null || verseSn == null) {
      return;
    }

    _verseSn = verseSn;
    ref.read(readingProgressRepositoryProvider).saveCurrentLocation(
          ReadingLocation(
            resourceId: widget.resourceId,
            volumeSn: volumeSn,
            chapterSn: chapterSn,
            verseSn: verseSn,
            scrollOffset:
                _scrollController.hasClients ? _scrollController.offset : 0,
            progressPercent: _chapterProgress(
              _scrollController.hasClients ? _scrollController.offset : 0,
            ),
          ),
        );
  }

  void _handleReaderTap(TapUpDetails details) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final tapY = details.globalPosition.dy;

    if (tapY < screenHeight * 0.32 || tapY > screenHeight * 0.68) {
      return;
    }

    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(appSettingProvider).valueOrNull;
    final fontSize = setting?.fontSize ?? AppDimens.readerFontSize;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: _handleReaderTap,
          child: FutureBuilder<_ReaderChapter>(
            future: _chapter,
            builder: (context, snapshot) {
              final chapter = snapshot.data;
              if (chapter != null) {
                _restorePositionIfNeeded();
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    toolbarHeight: AppDimens.appBarHeight,
                    title: _ReaderTitle(chapter: chapter),
                    titleSpacing: AppDimens.pagePaddingX,
                    centerTitle: false,
                    pinned: true,
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.pagePaddingX),
                        child: Center(
                          child: Text(
                            '\u8bfb\u53d6\u5931\u8d25\n${snapshot.error}',
                          ),
                        ),
                      ),
                    )
                  else if (chapter == null || chapter.verses.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('\u672c\u7ae0\u6682\u65e0\u7ecf\u6587'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppDimens.pagePaddingX,
                        AppDimens.pagePaddingY,
                        AppDimens.pagePaddingX,
                        _showControls ? 92 : AppDimens.pagePaddingY,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final begin = Offset(
                              0.06 * _chapterDirection,
                              0,
                            );
                            final slide = Tween<Offset>(
                              begin: begin,
                              end: Offset.zero,
                            ).animate(animation);

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child: _VerseColumn(
                            key: ValueKey('${_volumeSn}_$_chapterSn'),
                            verses: chapter.verses,
                            verseKeys: _verseKeys,
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _showControls
          ? SafeArea(
              top: false,
              child: FutureBuilder<_ReaderChapter>(
                future: _chapter,
                builder: (context, snapshot) {
                  final chapter = snapshot.data;

                  return _ReaderControls(
                    enabled: chapter != null,
                    isSpeaking: _isSpeaking,
                    onPrevious: chapter == null
                        ? null
                        : () => _openPreviousChapter(chapter),
                    onIndex: chapter == null ? null : () => _showIndex(chapter),
                    onReadAloud: chapter == null
                        ? null
                        : () => _toggleReadAloud(chapter),
                    onTextSettings: _showTextSettings,
                    onNext: chapter == null
                        ? null
                        : () => _openNextChapter(chapter),
                  );
                },
              ),
            )
          : null,
    );
  }
}

class _ReaderTitle extends StatelessWidget {
  const _ReaderTitle({required this.chapter});

  final _ReaderChapter? chapter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = chapter?.title ?? '\u5723\u7ecf';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerseColumn extends StatelessWidget {
  const _VerseColumn({
    super.key,
    required this.verses,
    required this.verseKeys,
    required this.fontSize,
  });

  final List<BibleVerseRecord> verses;
  final Map<int, GlobalKey> verseKeys;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final verse in verses) ...[
          _VerseLine(
            key: verseKeys[verse.verseSn],
            verse: verse,
            fontSize: fontSize,
          ),
          if (verse != verses.last)
            const SizedBox(height: AppDimens.verseSpacing),
        ],
      ],
    );
  }
}

class _VerseLine extends StatelessWidget {
  const _VerseLine({
    super.key,
    required this.verse,
    required this.fontSize,
  });

  final BibleVerseRecord verse;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppDimens.verseNumberSize,
          height: AppDimens.verseNumberSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${verse.verseSn}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            verse.lection ?? '',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: fontSize,
              height: AppDimens.readerLineHeight,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderControls extends StatelessWidget {
  const _ReaderControls({
    required this.enabled,
    required this.isSpeaking,
    required this.onPrevious,
    required this.onIndex,
    required this.onReadAloud,
    required this.onTextSettings,
    required this.onNext,
  });

  final bool enabled;
  final bool isSpeaking;
  final VoidCallback? onPrevious;
  final VoidCallback? onIndex;
  final VoidCallback? onReadAloud;
  final VoidCallback onTextSettings;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: SizedBox(
          height: AppDimens.bottomBarHeight,
          child: Row(
            children: [
              _ToolbarButton(
                icon: Icons.chevron_left,
                label: '\u4e0a\u4e00\u7ae0',
                onPressed: enabled ? onPrevious : null,
              ),
              _ToolbarButton(
                icon: Icons.list_alt_outlined,
                label: '\u76ee\u5f55',
                onPressed: enabled ? onIndex : null,
              ),
              _ToolbarButton(
                icon: isSpeaking
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined,
                label: isSpeaking ? '\u505c\u6b62' : '\u6717\u8bfb',
                onPressed: enabled ? onReadAloud : null,
              ),
              _ToolbarButton(
                label: 'Aa',
                onPressed: onTextSettings,
              ),
              _ToolbarButton(
                icon: Icons.chevron_right,
                iconAlignment: IconAlignment.end,
                label: '\u4e0b\u4e00\u7ae0',
                onPressed: enabled ? onNext : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAlignment = IconAlignment.start,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconAlignment iconAlignment;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );

    return Expanded(
      child: icon == null
          ? TextButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : TextButton.icon(
              onPressed: onPressed,
              style: style,
              iconAlignment: iconAlignment,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _BibleIndexSheet extends StatefulWidget {
  const _BibleIndexSheet({
    required this.books,
    required this.selectedVolumeSn,
    required this.selectedChapterSn,
  });

  final List<BibleBookRecord> books;
  final int selectedVolumeSn;
  final int selectedChapterSn;

  @override
  State<_BibleIndexSheet> createState() => _BibleIndexSheetState();
}

class _BibleIndexSheetState extends State<_BibleIndexSheet> {
  late BibleBookRecord _selectedBook;
  late int _selectedTestament;
  late ScrollController _bookScrollController;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.books.firstWhere(
      (book) => book.sn == widget.selectedVolumeSn,
      orElse: () => widget.books.first,
    );
    _selectedTestament = _selectedBook.newOrOld;
    _bookScrollController = ScrollController(
      initialScrollOffset: _initialBookListOffset(),
    );
  }

  @override
  void dispose() {
    _bookScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapterCount = _selectedBook.chapterNumber ?? 1;
    final colorScheme = Theme.of(context).colorScheme;
    final books = _booksForTestament(_selectedTestament);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.indexPadding,
          0,
          AppDimens.indexPadding,
          AppDimens.indexPadding,
        ),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('旧约')),
                  ButtonSegment(value: 1, label: Text('新约')),
                ],
                selected: {_selectedTestament},
                onSelectionChanged: (values) {
                  final testament = values.first;
                  final nextBooks = _booksForTestament(testament);
                  if (nextBooks.isEmpty) {
                    return;
                  }

                  setState(() {
                    _selectedTestament = testament;
                    _selectedBook = nextBooks.first;
                    _bookScrollController.jumpTo(0);
                  });
                },
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: AppDimens.indexBookWidth,
                    child: ListView.separated(
                      controller: _bookScrollController,
                      itemCount: books.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final book = books[index];
                        final selected = book.sn == _selectedBook.sn;

                        return _BookIndexTile(
                          bookName: _formatBookName(book),
                          selected: selected,
                          onTap: () {
                            setState(() => _selectedBook = book);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: VerticalDivider(color: colorScheme.outlineVariant),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 14),
                          child: _ChapterHeader(
                            book: _selectedBook,
                            chapterCount: chapterCount,
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = (constraints.maxWidth / 54)
                                  .floor()
                                  .clamp(3, 5);

                              return GridView.builder(
                                padding: EdgeInsets.zero,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                                itemCount: chapterCount,
                                itemBuilder: (context, index) {
                                  final chapterSn = index + 1;
                                  final selected = _selectedBook.sn ==
                                          widget.selectedVolumeSn &&
                                      chapterSn == widget.selectedChapterSn;

                                  return Center(
                                    child: _ChapterButton(
                                      chapterSn: chapterSn,
                                      selected: selected,
                                      onPressed: () {
                                        Navigator.of(context).pop(
                                          _ChapterSelection(
                                            volumeSn: _selectedBook.sn,
                                            chapterSn: chapterSn,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _initialBookListOffset() {
    final books = _booksForTestament(_selectedBook.newOrOld);
    final index = books.indexWhere((book) => book.sn == _selectedBook.sn);
    if (index <= 2) {
      return 0;
    }

    return (index - 2) * 44;
  }

  List<BibleBookRecord> _booksForTestament(int testament) {
    return widget.books.where((book) => book.newOrOld == testament).toList();
  }

  String _formatBookName(BibleBookRecord book) {
    final fullName = book.fullName;
    final shortName = book.shortName;

    if (fullName != null && shortName != null && fullName != shortName) {
      return '$fullName ($shortName)';
    }

    return fullName ?? shortName ?? '${book.sn}';
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.book,
    required this.chapterCount,
  });

  final BibleBookRecord book;
  final int chapterCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullName = book.fullName ?? book.shortName ?? '${book.sn}';
    final shortName = book.shortName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          shortName == null
              ? '共 $chapterCount 章'
              : '$shortName · 共 $chapterCount 章',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _BookIndexTile extends StatelessWidget {
  const _BookIndexTile({
    required this.bookName,
    required this.selected,
    required this.onTap,
  });

  final String bookName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: selected ? 34 : 0,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bookName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterButton extends StatelessWidget {
  const _ChapterButton({
    required this.chapterSn,
    required this.selected,
    required this.onPressed,
  });

  final int chapterSn;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox.square(
      dimension: AppDimens.chapterButtonSize,
      child: Material(
        color: selected ? colorScheme.primary : colorScheme.surfaceContainerLow,
        shape: CircleBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              '$chapterSn',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderTextSettingsSheet extends ConsumerWidget {
  const _ReaderTextSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(appSettingProvider);
    final controller = ref.watch(settingControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: setting.when(
        data: (value) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u5b57\u53f7',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Slider(
              min: 14,
              max: 28,
              divisions: 14,
              value: value.fontSize.clamp(14, 28).toDouble(),
              onChanged: controller.setFontSize,
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Text('$error'),
      ),
    );
  }
}

class _ReaderChapter {
  const _ReaderChapter({
    required this.books,
    required this.book,
    required this.chapterSn,
    required this.verses,
  });

  final List<BibleBookRecord> books;
  final BibleBookRecord? book;
  final int chapterSn;
  final List<BibleVerseRecord> verses;

  String get bookName => book?.fullName ?? book?.shortName ?? '\u5723\u7ecf';
  String get chapterLabel => '\u7b2c$chapterSn\u7ae0';
  String get title => '$bookName · $chapterLabel';
}

class _ChapterSelection {
  const _ChapterSelection({
    required this.volumeSn,
    required this.chapterSn,
  });

  final int volumeSn;
  final int chapterSn;
}
