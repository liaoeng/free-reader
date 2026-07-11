import 'dart:io';

import 'package:free_reader/database/connections/database_paths.dart';
import 'package:free_reader/features/reader/data/resource_reader.dart';

class TextResourceReader extends ResourceReader {
  TextResourceReader(super.resource);

  File? _file;

  @override
  Future<void> open() async {
    _file = await DatabasePaths.fileForResourcePath(resource.filePath);
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
    return [
      ResourceCatalogItem(
        locator: 'text:0',
        title: resource.name,
      ),
    ];
  }

  @override
  Future<ResourceContent> getContent(String locator) async {
    final file =
        _file ?? await DatabasePaths.fileForResourcePath(resource.filePath);
    final text = await file.readAsString();
    return ResourceContent(
      locator: 'text:0',
      title: resource.name,
      plainText: text,
    );
  }

  @override
  Future<List<ResourceContent>> search(String keyword) async {
    final content = await getContent('text:0');
    if (!content.plainText.contains(keyword)) {
      return const [];
    }
    return [content];
  }

  @override
  Future<void> close() async {}
}
