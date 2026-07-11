import 'dart:io';

import 'package:free_reader/database/connections/database_paths.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/resources/data/file_picker_service.dart';
import 'package:free_reader/features/resources/data/resource_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

class ResourceImportService {
  const ResourceImportService({
    required ResourceRepository resourceRepository,
    required FilePickerService filePickerService,
  })  : _resourceRepository = resourceRepository,
        _filePickerService = filePickerService;

  final ResourceRepository _resourceRepository;
  final FilePickerService _filePickerService;

  Future<ResourceRecord?> pickAndImport() async {
    final picked = await _filePickerService.pickResourceFile();
    if (picked == null) {
      return null;
    }

    final source = File(picked.tempPath);
    if (!await source.exists()) {
      throw StateError('Selected file is not available.');
    }

    final fileFormat = _formatForFileName(picked.name);
    final resourceType = _resourceTypeFor(
      fileFormat: fileFormat,
      filePath: source.path,
    );
    final filePath = await _copyIntoResourceDirectory(
      source: source,
      originalName: picked.name,
      resourceType: resourceType,
    );
    final target = await DatabasePaths.fileForResourcePath(filePath);
    final stat = await target.stat();

    return _resourceRepository.registerImportedResource(
      name: p.basenameWithoutExtension(picked.name),
      resourceType: resourceType,
      fileFormat: fileFormat,
      filePath: filePath,
      fileSize: stat.size,
    );
  }

  String _formatForFileName(String name) {
    return switch (p.extension(name).toLowerCase()) {
      '.db' || '.sqlite' || '.sqlite3' => 'SQLITE',
      '.epub' => 'EPUB',
      '.pdf' => 'PDF',
      '.txt' => 'TXT',
      '.md' || '.markdown' => 'MD',
      _ => 'OTHER',
    };
  }

  String _resourceTypeFor({
    required String fileFormat,
    required String filePath,
  }) {
    if (fileFormat == 'SQLITE') {
      return _isBibleSqlite(filePath) ? 'BIBLE' : 'HYMN';
    }
    return switch (fileFormat) {
      'EPUB' => 'EPUB',
      'PDF' => 'PDF',
      'TXT' => 'TXT',
      'MD' => 'MARKDOWN',
      _ => 'OTHER',
    };
  }

  bool _isBibleSqlite(String filePath) {
    sqlite.Database? database;
    try {
      database = sqlite.sqlite3.open(filePath, mode: sqlite.OpenMode.readOnly);
      final tables = database
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          )
          .map((row) => '${row['name']}'.toLowerCase())
          .toSet();
      return tables.contains('bible') && tables.contains('bibleid');
    } catch (_) {
      return false;
    } finally {
      database?.close();
    }
  }

  Future<String> _copyIntoResourceDirectory({
    required File source,
    required String originalName,
    required String resourceType,
  }) async {
    final directoryName = switch (resourceType) {
      'BIBLE' => 'bible',
      'HYMN' => 'hymn',
      _ => 'books',
    };
    final resourcesDirectory = await DatabasePaths.resourcesDirectory();
    final targetDirectory = Directory(
      p.join(resourcesDirectory.path, directoryName),
    );
    await targetDirectory.create(recursive: true);

    final safeName = _safeFileName(originalName);
    final target = await _uniqueTarget(targetDirectory, safeName);
    await source.copy(target.path);

    return p
        .join('resources', directoryName, p.basename(target.path))
        .replaceAll('\\', '/');
  }

  Future<File> _uniqueTarget(Directory directory, String fileName) async {
    final extension = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);
    var candidate = File(p.join(directory.path, fileName));
    var index = 2;
    while (await candidate.exists()) {
      candidate = File(p.join(directory.path, '$baseName-$index$extension'));
      index++;
    }
    return candidate;
  }

  String _safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'resource' : sanitized;
  }
}
