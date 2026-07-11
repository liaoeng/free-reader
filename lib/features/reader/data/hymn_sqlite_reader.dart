import 'package:free_reader/database/connections/database_paths.dart';
import 'package:free_reader/features/reader/data/resource_reader.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class HymnSqliteReader extends ResourceReader {
  HymnSqliteReader(super.resource);

  sqlite.Database? _database;
  _HymnSchema? _schema;

  @override
  Future<void> open() async {
    if (_database != null) {
      return;
    }
    final file = await DatabasePaths.fileForResourcePath(resource.filePath);
    _database = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    _schema = _detectSchema(_database!);
  }

  @override
  Future<ResourceMetadata> getMetadata() async {
    return ResourceMetadata(
      title: resource.name,
      language: resource.language,
      author: resource.author,
    );
  }

  @override
  Future<List<ResourceCatalogItem>> getCatalog() async {
    final database = _requireDatabase();
    final schema = _requireSchema();
    final rows = database.select(
      'SELECT ${schema.idExpression} AS locator_id, '
      '${schema.titleExpression} AS title FROM ${_quote(schema.tableName)} '
      'ORDER BY ${schema.orderExpression}',
    );

    return [
      for (final row in rows)
        ResourceCatalogItem(
          locator: 'hymn:${row['locator_id']}',
          title: _catalogTitle(row['locator_id'], row['title']),
        ),
    ];
  }

  @override
  Future<ResourceContent> getContent(String locator) async {
    final database = _requireDatabase();
    final schema = _requireSchema();
    final id = locator.split(':').length > 1 ? locator.split(':')[1] : locator;
    final rows = database.select(
      'SELECT ${schema.idExpression} AS locator_id, '
      '${schema.titleExpression} AS title, '
      '${schema.contentExpression} AS content '
      'FROM ${_quote(schema.tableName)} '
      'WHERE ${schema.idExpression} = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) {
      throw StateError('Hymn not found: $locator');
    }

    final row = rows.first;
    return ResourceContent(
      locator: 'hymn:${row['locator_id']}',
      title: _catalogTitle(row['locator_id'], row['title']),
      plainText: '${row['content'] ?? ''}',
    );
  }

  @override
  Future<List<ResourceContent>> search(String keyword) async {
    final database = _requireDatabase();
    final schema = _requireSchema();
    final rows = database.select(
      'SELECT ${schema.idExpression} AS locator_id '
      'FROM ${_quote(schema.tableName)} '
      'WHERE ${schema.contentExpression} LIKE ? '
      'OR ${schema.titleExpression} LIKE ? '
      'ORDER BY ${schema.orderExpression} LIMIT 50',
      ['%$keyword%', '%$keyword%'],
    );

    return [
      for (final row in rows) await getContent('hymn:${row['locator_id']}'),
    ];
  }

  @override
  Future<void> close() async {
    _database?.close();
    _database = null;
    _schema = null;
  }

  sqlite.Database _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('Reader is not open.');
    }
    return database;
  }

  _HymnSchema _requireSchema() {
    final schema = _schema;
    if (schema == null) {
      throw StateError('Could not detect hymn SQLite schema.');
    }
    return schema;
  }

  _HymnSchema? _detectSchema(sqlite.Database database) {
    final tables = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    );

    for (final tableRow in tables) {
      final tableName = '${tableRow['name']}';
      final columns = database
          .select('PRAGMA table_info(${_quote(tableName)})')
          .map((row) => _SqliteColumn(
                name: '${row['name']}',
                type: '${row['type']}'.toLowerCase(),
                primaryKey: row['pk'] == 1,
              ))
          .toList();
      final textColumns = columns.where((column) => column.isTextLike).toList();
      if (textColumns.isEmpty) {
        continue;
      }

      final idColumn = _pickColumn(columns, const [
        'id',
        'sn',
        'no',
        'num',
        'number',
        'hymnid',
        'songid',
      ]);
      final titleColumn = _pickColumn(textColumns, const [
        'title',
        'name',
        'caption',
        'subject',
      ]);
      final contentColumn = _pickColumn(textColumns, const [
            'content',
            'lyrics',
            'lyric',
            'text',
            'body',
            'words',
          ]) ??
          textColumns.firstWhere(
            (column) => column.name != titleColumn?.name,
            orElse: () => textColumns.first,
          );

      final idExpression = idColumn == null ? 'rowid' : _quote(idColumn.name);
      final titleExpression = titleColumn == null
          ? idExpression
          : 'COALESCE(${_quote(titleColumn.name)}, $idExpression)';
      final contentExpression = _quote(contentColumn.name);

      return _HymnSchema(
        tableName: tableName,
        idExpression: idExpression,
        titleExpression: titleExpression,
        contentExpression: contentExpression,
        orderExpression: idExpression,
      );
    }

    return null;
  }

  _SqliteColumn? _pickColumn(List<_SqliteColumn> columns, List<String> names) {
    final lowerNames = names.map((name) => name.toLowerCase()).toSet();
    for (final column in columns) {
      if (lowerNames.contains(column.name.toLowerCase())) {
        return column;
      }
    }
    for (final column in columns) {
      if (column.primaryKey) {
        return column;
      }
    }
    return null;
  }

  String _catalogTitle(Object? id, Object? title) {
    final titleText = '${title ?? ''}'.trim();
    if (titleText.isNotEmpty && titleText != '$id') {
      return titleText;
    }
    return '第$id首';
  }

  String _quote(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }
}

class _HymnSchema {
  const _HymnSchema({
    required this.tableName,
    required this.idExpression,
    required this.titleExpression,
    required this.contentExpression,
    required this.orderExpression,
  });

  final String tableName;
  final String idExpression;
  final String titleExpression;
  final String contentExpression;
  final String orderExpression;
}

class _SqliteColumn {
  const _SqliteColumn({
    required this.name,
    required this.type,
    required this.primaryKey,
  });

  final String name;
  final String type;
  final bool primaryKey;

  bool get isTextLike {
    return type.contains('char') ||
        type.contains('clob') ||
        type.contains('text') ||
        type.isEmpty;
  }
}
