import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/bible_database.dart';
import 'package:free_reader/database/user_database.dart';

final bibleDatabaseProvider = Provider<BibleDatabase>((ref) {
  final database = BibleDatabase();
  ref.onDispose(database.close);
  return database;
});

final userDatabaseProvider = Provider<UserDatabase>((ref) {
  final database = UserDatabase();
  ref.onDispose(database.close);
  return database;
});
