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

  Future<ResourceRecord> registerImportedResource({
    required String name,
    required String resourceType,
    required String fileFormat,
    required String filePath,
    required int fileSize,
  }) async {
    final now = DateTime.now();
    final id = _resourceId(resourceType, name, now);
    final companion = ResourcesCompanion.insert(
      id: id,
      name: name,
      resourceType: resourceType,
      fileFormat: fileFormat,
      filePath: filePath,
      fileSize: Value(fileSize),
      createdAt: now,
      updatedAt: now,
      allowExport: const Value(true),
    );

    await _database.into(_database.resources).insert(companion);
    final resource = await getResource(id);
    if (resource == null) {
      throw StateError('Imported resource could not be loaded.');
    }
    return resource;
  }

  Future<void> renameResource({
    required String resourceId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Resource name cannot be empty.');
    }

    await (_database.update(_database.resources)
          ..where((resource) => resource.id.equals(resourceId)))
        .write(
      ResourcesCompanion(
        name: Value(trimmed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteResource(ResourceRecord resource) async {
    if (resource.id == ResourceConstants.builtinBibleId) {
      throw StateError('The built-in Bible cannot be deleted.');
    }

    await _database.transaction(() async {
      await (_database.delete(_database.readingProgress)
            ..where((progress) => progress.resourceId.equals(resource.id)))
          .go();
      await (_database.delete(_database.bookmarks)
            ..where((bookmark) => bookmark.resourceId.equals(resource.id)))
          .go();
      await (_database.delete(_database.favorites)
            ..where((favorite) => favorite.resourceId.equals(resource.id)))
          .go();
      await (_database.delete(_database.highlights)
            ..where((highlight) => highlight.resourceId.equals(resource.id)))
          .go();
      await (_database.delete(_database.resources)
            ..where((candidate) => candidate.id.equals(resource.id)))
          .go();
    });

    final file = await fileFor(resource);
    if (await file.exists()) {
      await file.delete();
    }
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

  String _resourceId(String resourceType, String name, DateTime now) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final safeSlug = slug.isEmpty ? 'resource' : slug;
    return '${resourceType.toLowerCase()}-$safeSlug-${now.microsecondsSinceEpoch}';
  }
}
