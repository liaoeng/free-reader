class ReadingLocation {
  const ReadingLocation({
    required this.volumeSn,
    required this.chapterSn,
    required this.verseSn,
    this.scrollOffset = 0,
  });

  final int volumeSn;
  final int chapterSn;
  final int verseSn;
  final double scrollOffset;
}
