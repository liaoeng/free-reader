import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabasePaths {
  const DatabasePaths._();

  static const bibleAssetPath = 'assets/db/bible.db';
  static const bibleFileName = 'bible.db';
  static const userFileName = 'user.db';
  static const resourcesDirectoryName = 'resources';
  static const builtinBibleResourcePath = 'resources/bible/cuv.db';

  static Future<File> bibleDatabaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, bibleFileName));
  }

  static Future<File> builtinBibleResourceFile() {
    return fileForResourcePath(builtinBibleResourcePath);
  }

  static Future<Directory> resourcesDirectory() async {
    final directory = await getApplicationSupportDirectory();
    return Directory(p.join(directory.path, resourcesDirectoryName));
  }

  static Future<File> fileForResourcePath(String filePath) async {
    if (p.isAbsolute(filePath)) {
      return File(filePath);
    }

    final directory = await getApplicationSupportDirectory();
    final normalizedPath = filePath.replaceAll('/', p.separator);
    return File(p.join(directory.path, normalizedPath));
  }

  static Future<File> userDatabaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, userFileName));
  }
}
