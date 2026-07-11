import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/data/bible_sqlite_reader.dart';
import 'package:free_reader/features/reader/data/hymn_sqlite_reader.dart';
import 'package:free_reader/features/reader/data/resource_reader.dart';
import 'package:free_reader/features/reader/data/text_resource_reader.dart';

class ResourceReaderFactory {
  const ResourceReaderFactory();

  ResourceReader create(ResourceRecord resource) {
    if (resource.resourceType == 'BIBLE' && resource.fileFormat == 'SQLITE') {
      return BibleSqliteReader(resource);
    }
    if (resource.resourceType == 'HYMN' && resource.fileFormat == 'SQLITE') {
      return HymnSqliteReader(resource);
    }
    if (resource.fileFormat == 'TXT' || resource.fileFormat == 'MD') {
      return TextResourceReader(resource);
    }

    throw UnsupportedError(
      'Unsupported resource: ${resource.resourceType}/${resource.fileFormat}',
    );
  }
}
