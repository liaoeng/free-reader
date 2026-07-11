import 'package:drift/drift.dart';

@DataClassName('ResourceRecord')
class Resources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get resourceType => text().named('resource_type')();
  TextColumn get fileFormat => text().named('file_format')();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get version => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().named('cover_path').nullable()();
  IntColumn get fileSize =>
      integer().named('file_size').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  BoolColumn get allowExport =>
      boolean().named('allow_export').withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReadingProgressRecord')
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get resourceId => text()
      .named('resource_id')
      .withDefault(const Constant('builtin-bible-cuv'))();
  TextColumn get locator => text().withDefault(const Constant(''))();
  IntColumn get volumeSn => integer().named('volume_sn')();
  IntColumn get chapterSn => integer().named('chapter_sn')();
  IntColumn get verseSn => integer().named('verse_sn')();
  IntColumn get chapter => integer().nullable()();
  IntColumn get page => integer().nullable()();
  RealColumn get scrollOffset =>
      real().named('scroll_offset').withDefault(const Constant(0))();
  RealColumn get progressPercent =>
      real().named('progress_percent').withDefault(const Constant(0))();
  DateTimeColumn get lastReadTime => dateTime().named('last_read_time')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {resourceId},
      ];
}

@DataClassName('BookmarkRecord')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get resourceId => text().named('resource_id')();
  TextColumn get locator => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}

@DataClassName('FavoriteRecord')
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get resourceId => text().named('resource_id')();
  TextColumn get locator => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}

@DataClassName('HighlightRecord')
class Highlights extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get resourceId => text().named('resource_id')();
  TextColumn get locator => text()();
  IntColumn get startOffset => integer().named('start_offset').nullable()();
  IntColumn get endOffset => integer().named('end_offset').nullable()();
  TextColumn get selectedText => text().named('selected_text').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}

@DataClassName('ExportRecord')
class ExportRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get resourceId => text().named('resource_id')();
  TextColumn get resourceName => text().named('resource_name')();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get directoryPath => text().named('directory_path')();
  IntColumn get fileSize =>
      integer().named('file_size').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
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
