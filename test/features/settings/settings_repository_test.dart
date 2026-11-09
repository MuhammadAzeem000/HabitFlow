import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/features/settings/data/settings_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('first load creates defaults', () async {
    final s = await repo.load();
    expect(s.theme, ThemePreference.system);
    expect(s.timeFormat, TimeFormatPreference.system);
    expect(s.notificationsEnabled, isTrue);
  });

  test('saved settings are returned on next load', () async {
    final s = await repo.load();
    await repo.save(s.copyWith(theme: ThemePreference.dark));
    expect((await repo.load()).theme, ThemePreference.dark);
  });
}
