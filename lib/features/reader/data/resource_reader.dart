import 'package:free_reader/database/user_database.dart';

class ResourceMetadata {
  const ResourceMetadata({
    required this.title,
    this.language,
    this.author,
  });

  final String title;
  final String? language;
  final String? author;
}

class ResourceCatalogItem {
  const ResourceCatalogItem({
    required this.locator,
    required this.title,
    this.children = const [],
  });

  final String locator;
  final String title;
  final List<ResourceCatalogItem> children;
}

class ResourceContent {
  const ResourceContent({
    required this.locator,
    required this.title,
    required this.plainText,
  });

  final String locator;
  final String title;
  final String plainText;
}

abstract class ResourceReader {
  ResourceReader(this.resource);

  final ResourceRecord resource;

  Future<void> open();

  Future<ResourceMetadata> getMetadata();

  Future<List<ResourceCatalogItem>> getCatalog();

  Future<ResourceContent> getContent(String locator);

  Future<List<ResourceContent>> search(String keyword);

  Future<void> close();
}
