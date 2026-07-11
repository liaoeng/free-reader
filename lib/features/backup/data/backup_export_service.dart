import 'dart:convert';
import 'dart:io';

import 'package:free_reader/core/archive/simple_zip_writer.dart';
import 'package:free_reader/database/connections/database_paths.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/resources/data/resource_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupExportService {
  const BackupExportService(this._database);

  static const exportVersion = 2;

  final UserDatabase _database;

  Future<File> exportAll() async {
    final now = DateTime.now();
    final exportFile = await _createExportFile(now);
    final zip = SimpleZipWriter();
    final resources = await _addRegisteredResources(zip);

    zip
      ..addFile(
        'manifest.json',
        _jsonBytes({
          'app': 'Free Reader',
          'app_version': '0.1.0',
          'export_version': exportVersion,
          'exported_at': now.toIso8601String(),
          'resources': resources,
        }),
      )
      ..addFile('settings.json', await _settingsBytes())
      ..addFile(
          'reading_progress.json',
          await _tableBytes(
            _database.select(_database.readingProgress).get(),
          ))
      ..addFile(
          'bookmarks.json',
          await _tableBytes(
            _database.select(_database.bookmarks).get(),
          ))
      ..addFile(
          'favorites.json',
          await _tableBytes(
            _database.select(_database.favorites).get(),
          ))
      ..addFile(
          'highlights.json',
          await _tableBytes(
            _database.select(_database.highlights).get(),
          ));

    await exportFile.writeAsBytes(zip.build(), flush: true);
    return exportFile;
  }

  Future<File> _createExportFile(DateTime now) async {
    final baseDirectory = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      p.join(baseDirectory.path, 'FreeReader', 'exports'),
    );
    await exportDirectory.create(recursive: true);

    return File(
      p.join(exportDirectory.path, 'free-reader-${_stamp(now)}.frpkg'),
    );
  }

  Future<List<Map<String, Object?>>> _addRegisteredResources(
    SimpleZipWriter zip,
  ) async {
    await ResourceRepository(_database).ensureBuiltInResources();
    final records = await _database.select(_database.resources).get();
    final resources = <Map<String, Object?>>[];

    for (final resource in records) {
      final file = await DatabasePaths.fileForResourcePath(resource.filePath);
      if (!await file.exists()) {
        continue;
      }

      final resourcePath = resource.filePath.replaceAll('\\', '/');
      zip.addFile(resourcePath, await file.readAsBytes());
      resources.add({
        'id': resource.id,
        'title': resource.name,
        'file_name': p.basename(file.path),
        'path': resourcePath,
        'type': resource.resourceType,
        'format': resource.fileFormat,
        'language': resource.language,
        'version': resource.version,
      });
    }

    return resources;
  }

  Future<List<int>> _settingsBytes() async {
    final settings = await _database.select(_database.appSettings).get();
    return _jsonBytes(settings.map((setting) => setting.toJson()).toList());
  }

  Future<List<int>> _tableBytes<T>(
    Future<List<T>> records,
  ) async {
    final values = await records;
    return _jsonBytes(
      values.map((record) => (record as dynamic).toJson()).toList(),
    );
  }

  String _stamp(DateTime time) {
    return [
      time.year.toString().padLeft(4, '0'),
      time.month.toString().padLeft(2, '0'),
      time.day.toString().padLeft(2, '0'),
      '_',
      time.hour.toString().padLeft(2, '0'),
      time.minute.toString().padLeft(2, '0'),
      time.second.toString().padLeft(2, '0'),
    ].join();
  }

  List<int> _jsonBytes(Object value) {
    const encoder = JsonEncoder.withIndent('  ');
    return utf8.encode('${encoder.convert(value)}\n');
  }
}
