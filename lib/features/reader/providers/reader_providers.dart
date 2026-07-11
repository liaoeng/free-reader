import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/database_providers.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/reader/data/reading_progress_repository.dart';
import 'package:free_reader/features/reader/data/resource_reader_factory.dart';
import 'package:free_reader/features/reader/data/tts_service.dart';
import 'package:free_reader/features/resources/data/path_launcher_service.dart';
import 'package:free_reader/features/resources/data/resource_export_service.dart';
import 'package:free_reader/features/resources/data/resource_repository.dart';

final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository(ref.watch(userDatabaseProvider));
});

final resourcesProvider = StreamProvider<List<ResourceRecord>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchResources();
});

final resourceExportServiceProvider = Provider<ResourceExportService>((ref) {
  return ResourceExportService(ref.watch(userDatabaseProvider));
});

final exportRecordsProvider = StreamProvider<List<ExportRecord>>((ref) {
  return ref.watch(resourceExportServiceProvider).watchExportRecords();
});

final pathLauncherServiceProvider = Provider<PathLauncherService>((ref) {
  return const PathLauncherService();
});

final resourceReaderFactoryProvider = Provider<ResourceReaderFactory>((ref) {
  return const ResourceReaderFactory();
});

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository(ref.watch(userDatabaseProvider));
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

final latestReadingProgressProvider =
    StreamProvider<ReadingProgressRecord?>((ref) {
  return ref.watch(readingProgressRepositoryProvider).watchLatestProgress();
});
