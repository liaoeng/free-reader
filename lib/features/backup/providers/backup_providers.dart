import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/database/database_providers.dart';
import 'package:free_reader/features/backup/data/backup_export_service.dart';

final backupExportServiceProvider = Provider<BackupExportService>((ref) {
  return BackupExportService(ref.watch(userDatabaseProvider));
});
