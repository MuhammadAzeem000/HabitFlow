import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/settings/data/settings_repository.dart';

import 'helpers/pump_app.dart';
import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('launches to Today with an empty state from local data', (
    tester,
  ) async {
    await pumpApp(tester, db);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('shows habits stored in the local database', (tester) async {
    await tester.runAsync(
      () => HabitRepository(db).createHabit(
        const HabitDraft(
          name: 'Drink water',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      ),
    );
    await pumpApp(tester, db, clock: () => DateTime(2026, 11, 9, 9));
    expect(find.text('Drink water'), findsOneWidget);
  });

  testWidgets('navigates between all tabs', (tester) async {
    await pumpApp(tester, db);
    for (final (tab, title) in [
      ('Habits', 'Manage your habits'),
      ('Calendar', 'Your history'),
      ('Settings', 'Appearance'),
      ('Today', 'No habits yet'),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: 'tab $tab');
    }
  });

  testWidgets('theme choice applies immediately and persists', (tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await settle(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    final saved = await tester.runAsync(() => SettingsRepository(db).load());
    expect(saved!.theme, ThemePreference.dark);
  });
}
