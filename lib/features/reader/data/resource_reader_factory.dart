import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/data/bible_sqlite_reader.dart';
import 'package:free_reader/features/reader/data/resource_reader.dart';

class ResourceReaderFactory {
  const ResourceReaderFactory();

  ResourceReader create(ResourceRecord resource) {
    if (resource.resourceType == 'BIBLE' && resource.fileFormat == 'SQLITE') {
      return BibleSqliteReader(resource);
    }

    throw UnsupportedError(
      'Unsupported resource: ${resource.resourceType}/${resource.fileFormat}',
    );
  }
}
