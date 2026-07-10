import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabasePaths {
  const DatabasePaths._();

  static const bibleAssetPath = 'assets/db/bible.db';
  static const bibleFileName = 'bible.db';
  static const userFileName = 'user.db';

  static Future<File> bibleDatabaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, bibleFileName));
  }

  static Future<File> userDatabaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, userFileName));
  }
}
