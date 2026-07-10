import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/core/theme/theme_mode_codec.dart';
import 'package:free_reader/database/database_providers.dart';
import 'package:free_reader/database/user_database.dart';
import 'package:free_reader/features/setting/data/setting_repository.dart';

final settingRepositoryProvider = Provider<SettingRepository>((ref) {
  return SettingRepository(ref.watch(userDatabaseProvider));
});

final appSettingProvider = StreamProvider<AppSettingRecord>((ref) {
  return ref.watch(settingRepositoryProvider).watchSettings();
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final setting = ref.watch(appSettingProvider);
  return setting.maybeWhen(
    data: (value) => ThemeModeCodec.decode(value.theme),
    orElse: () => ThemeMode.system,
  );
});

final settingControllerProvider = Provider<SettingController>((ref) {
  return SettingController(ref.watch(settingRepositoryProvider));
});

class SettingController {
  const SettingController(this._repository);

  final SettingRepository _repository;

  Future<void> setDarkModeEnabled(bool enabled) {
    return _repository.updateTheme(
      enabled ? ThemeModeCodec.dark : ThemeModeCodec.light,
    );
  }

  Future<void> setFontSize(double fontSize) {
    return _repository.updateFontSize(fontSize);
  }
}
