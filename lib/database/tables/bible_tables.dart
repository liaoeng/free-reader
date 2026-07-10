import 'package:drift/drift.dart';

@DataClassName('BibleBookRecord')
class BibleBooks extends Table {
  @override
  String get tableName => 'BibleID';

  IntColumn get sn => integer().named('SN')();
  IntColumn get kindSn => integer().named('KindSN').nullable()();
  IntColumn get chapterNumber => integer().named('ChapterNumber').nullable()();
  IntColumn get newOrOld => integer().named('NewOrOld')();
  TextColumn get pinYin => text().named('PinYin').nullable()();
  TextColumn get shortName => text().named('ShortName').nullable()();
  TextColumn get fullName => text().named('FullName').nullable()();

  @override
  Set<Column> get primaryKey => {sn};
}

@DataClassName('BibleVerseRecord')
class BibleVerses extends Table {
  @override
  String get tableName => 'Bible';

  IntColumn get id => integer().named('ID')();
  IntColumn get volumeSn => integer().named('VolumeSN')();
  IntColumn get chapterSn => integer().named('ChapterSN')();
  IntColumn get verseSn => integer().named('VerseSN')();
  TextColumn get lection => text().named('Lection').nullable()();
  RealColumn get soundBegin => real().named('SoundBegin').nullable()();
  RealColumn get soundEnd => real().named('SoundEnd').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
