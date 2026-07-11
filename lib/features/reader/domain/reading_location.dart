class ReadingLocation {
  const ReadingLocation({
    required this.resourceId,
    required this.volumeSn,
    required this.chapterSn,
    required this.verseSn,
    this.scrollOffset = 0,
    this.progressPercent = 0,
  });

  final String resourceId;
  final int volumeSn;
  final int chapterSn;
  final int verseSn;
  final double scrollOffset;
  final double progressPercent;

  String get locator => 'bible:$volumeSn:$chapterSn:$verseSn';
}
