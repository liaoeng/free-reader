import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:free_reader/database/connections/database_paths.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/resources/domain/resource_constants.dart';

class ResourceRepository {
  const ResourceRepository(this._database);

  final UserDatabase _database;

  Stream<List<ResourceRecord>> watchResources() async* {
    await ensureBuiltInResources();
    final query = _database.select(_database.resources)
      ..orderBy([(resource) => OrderingTerm.asc(resource.createdAt)]);
    yield* query.watch();
  }

  Future<List<ResourceRecord>> getResources() async {
    await ensureBuiltInResources();
    final query = _database.select(_database.resources)
      ..orderBy([(resource) => OrderingTerm.asc(resource.createdAt)]);
    return query.get();
  }

  Future<ResourceRecord?> getResource(String id) async {
    await ensureBuiltInResources();
    final query = _database.select(_database.resources)
      ..where((resource) => resource.id.equals(id))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<ResourceRecord> getBuiltInBible() async {
    final resource = await getResource(ResourceConstants.builtinBibleId);
    if (resource == null) {
      throw StateError('Built-in Bible resource is not registered.');
    }
    return resource;
  }

  Future<File> fileFor(ResourceRecord resource) {
    return DatabasePaths.fileForResourcePath(resource.filePath);
  }

  Future<void> ensureBuiltInResources() async {
    final file = await DatabasePaths.builtinBibleResourceFile();
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      final legacyFile = await DatabasePaths.bibleDatabaseFile();
      if (await legacyFile.exists()) {
        await legacyFile.copy(file.path);
      } else {
        final data = await rootBundle.load(DatabasePaths.bibleAssetPath);
        await file.writeAsBytes(
          data.buffer.asUint8List(),
          flush: true,
        );
      }
    }

    final stat = await file.stat();
    final existing = await (_database.select(_database.resources)
          ..where((resource) =>
              resource.id.equals(ResourceConstants.builtinBibleId))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null &&
        existing.filePath == DatabasePaths.builtinBibleResourcePath &&
        existing.fileSize == stat.size) {
      return;
    }

    final now = DateTime.now();
    final companion = ResourcesCompanion(
      id: const Value(ResourceConstants.builtinBibleId),
      name: const Value('和合本'),
      resourceType: const Value('BIBLE'),
      fileFormat: const Value('SQLITE'),
      filePath: const Value(DatabasePaths.builtinBibleResourcePath),
      version: const Value('CUV'),
      language: const Value('zh-CN'),
      author: const Value(''),
      coverPath: const Value.absent(),
      fileSize: Value(stat.size),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
      allowExport: const Value(true),
    );

    await _database.into(_database.resources).insertOnConflictUpdate(companion);
  }
}
