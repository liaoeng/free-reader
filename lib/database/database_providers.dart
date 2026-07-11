import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/user_database.dart';

final userDatabaseProvider = Provider<UserDatabase>((ref) {
  final database = UserDatabase();
  ref.onDispose(database.close);
  return database;
});
