import 'package:drift/drift.dart';
import 'package:free_reader/database/connections/bible_connection.dart';
import 'package:free_reader/database/tables/bible_tables.dart';

part 'bible_database.g.dart';

@DriftDatabase(tables: [BibleBooks, BibleVerses])
class BibleDatabase extends _$BibleDatabase {
  BibleDatabase() : super(openBibleConnection());

  @override
  int get schemaVersion => 1;
}
