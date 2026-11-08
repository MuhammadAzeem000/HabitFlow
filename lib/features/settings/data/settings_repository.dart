import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Single-row user preferences.
class SettingsRepository {
  SettingsRepository(this._db);

  static const settingsId = 'default';

  final AppDatabase _db;

  /// Loads settings, creating the default row on first launch.
  Future<UserSetting> load() async {
    final table = _db.userSettings;
    await _db
        .into(table)
        .insert(
          UserSettingsCompanion.insert(id: settingsId),
          mode: InsertMode.insertOrIgnore,
        );
    return (_db.select(
      table,
    )..where((s) => s.id.equals(settingsId))).getSingle();
  }

  Future<void> save(UserSetting settings) async {
    await _db.into(_db.userSettings).insertOnConflictUpdate(settings);
  }
}
