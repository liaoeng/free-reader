import 'package:drift/drift.dart';

@DataClassName('ReadingProgressRecord')
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get volumeSn => integer().named('volume_sn')();
  IntColumn get chapterSn => integer().named('chapter_sn')();
  IntColumn get verseSn => integer().named('verse_sn')();
  RealColumn get scrollOffset =>
      real().named('scroll_offset').withDefault(const Constant(0))();
  DateTimeColumn get lastReadTime => dateTime().named('last_read_time')();
}

@DataClassName('AppSettingRecord')
class AppSettings extends Table {
  @override
  String get tableName => 'app_setting';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get theme =>
      text().withDefault(const Constant('system')).withLength(max: 16)();
  RealColumn get fontSize =>
      real().named('font_size').withDefault(const Constant(18))();
  RealColumn get lineHeight =>
      real().named('line_height').withDefault(const Constant(1.7))();
  TextColumn get backgroundType => text()
      .named('background_type')
      .withDefault(const Constant('system'))
      .withLength(max: 24)();
}
