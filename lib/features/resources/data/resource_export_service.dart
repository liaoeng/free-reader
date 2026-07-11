import 'dart:io';

import 'package:drift/drift.dart';
import 'package:free_reader/database/connections/database_paths.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ResourceExportService {
  const ResourceExportService(this._database);

  final UserDatabase _database;

  Stream<List<ExportRecord>> watchExportRecords() {
    final query = _database.select(_database.exportRecords)
      ..orderBy([(record) => OrderingTerm.desc(record.createdAt)])
      ..limit(20);
    return query.watch();
  }

  Future<ExportRecord> exportResource(ResourceRecord resource) async {
    if (!resource.allowExport) {
      throw StateError('This resource does not allow export.');
    }

    final source = await DatabasePaths.fileForResourcePath(resource.filePath);
    if (!await source.exists()) {
      throw StateError('Resource file does not exist: ${resource.filePath}');
    }

    final now = DateTime.now();
    final directory = await _exportDirectory();
    await directory.create(recursive: true);

    final extension = p.extension(source.path);
    final fileName = '${_safeFileName(resource.name)}-${_stamp(now)}$extension';
    final target = File(p.join(directory.path, fileName));
    await source.copy(target.path);

    final stat = await target.stat();
    final id = await _database.into(_database.exportRecords).insert(
          ExportRecordsCompanion.insert(
            resourceId: resource.id,
            resourceName: resource.name,
            filePath: target.path,
            directoryPath: directory.path,
            fileSize: Value(stat.size),
            createdAt: now,
          ),
        );

    final query = _database.select(_database.exportRecords)
      ..where((record) => record.id.equals(id))
      ..limit(1);
    return query.getSingle();
  }

  Future<Directory> _exportDirectory() async {
    final baseDirectory = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    return Directory(p.join(baseDirectory.path, 'FreeReader', 'resources'));
  }

  String _safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'resource' : sanitized;
  }

  String _stamp(DateTime time) {
    return [
      time.year.toString().padLeft(4, '0'),
      time.month.toString().padLeft(2, '0'),
      time.day.toString().padLeft(2, '0'),
      '-',
      time.hour.toString().padLeft(2, '0'),
      time.minute.toString().padLeft(2, '0'),
      time.second.toString().padLeft(2, '0'),
    ].join();
  }
}
