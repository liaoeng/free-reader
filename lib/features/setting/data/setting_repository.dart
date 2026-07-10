import 'package:drift/drift.dart';
import 'package:free_reader/core/theme/theme_mode_codec.dart';
import 'package:free_reader/database/user_database.dart';

class SettingRepository {
  const SettingRepository(this._database);

  static const _settingId = 1;

  final UserDatabase _database;

  Stream<AppSettingRecord> watchSettings() async* {
    await _ensureDefaultSettings();

    final query = _database.select(_database.appSettings)
      ..where((setting) => setting.id.equals(_settingId))
      ..limit(1);

    yield* query.watchSingle();
  }

  Future<void> updateTheme(String theme) async {
    await _ensureDefaultSettings();
    await (_database.update(_database.appSettings)
          ..where((setting) => setting.id.equals(_settingId)))
        .write(AppSettingsCompanion(theme: Value(theme)));
  }

  Future<void> updateFontSize(double fontSize) async {
    await _ensureDefaultSettings();
    await (_database.update(_database.appSettings)
          ..where((setting) => setting.id.equals(_settingId)))
        .write(AppSettingsCompanion(fontSize: Value(fontSize)));
  }

  Future<void> _ensureDefaultSettings() {
    return _database.into(_database.appSettings).insertOnConflictUpdate(
          const AppSettingsCompanion(
            id: Value(_settingId),
            theme: Value(ThemeModeCodec.system),
            fontSize: Value(18),
            lineHeight: Value(1.7),
            backgroundType: Value('system'),
          ),
        );
  }
}
