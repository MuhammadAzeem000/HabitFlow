import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/challenges/data/challenge_repository.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/settings/data/settings_repository.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// HF-021: Flutter's accessibility guidelines on every main screen, in light
/// and dark themes, plus a 200% text-size layout check.
void main() {
  late AppDatabase db;
  DateTime clock() => DateTime(2026, 11, 12, 9);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester, {ThemePreference? theme}) =>
      tester.runAsync(() async {
        final habits = HabitRepository(db);
        final read = await habits.createHabit(
          const HabitDraft(
            name: 'Read 10 pages',
            frequency: HabitFrequency.daily,
            startDate: LocalDay(2026, 11, 1),
            reminderTime: '21:30',
          ),
        );
        await habits.createHabit(
          const HabitDraft(
            name: 'Gym',
            frequency: HabitFrequency.weekdays,
            targetDays: [1, 3, 4],
            startDate: LocalDay(2026, 11, 1),
          ),
        );
        for (var d = 5; d <= 11; d++) {
          await CompletionRepository(db).mark(read, LocalDay(2026, 11, d));
        }
        await ChallengeRepository(db).create(
          title: '30 days of Read 10 pages',
          habitId: read,
          startDate: const LocalDay(2026, 11, 10),
        );
        if (theme != null) {
          final s = await SettingsRepository(db).load();
          await SettingsRepository(db).save(s.copyWith(theme: theme));
        }
      });

  Future<void> checkGuidelines(WidgetTester tester, String screen) async {
    final handle = tester.ensureSemantics();
    await expectLater(
      tester,
      meetsGuideline(androidTapTargetGuideline),
      reason: '$screen: tap targets',
    );
    await expectLater(
      tester,
      meetsGuideline(labeledTapTargetGuideline),
      reason: '$screen: labels',
    );
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '$screen: contrast',
    );
    handle.dispose();
  }

  Future<void> visitAll(
    WidgetTester tester,
    Future<void> Function(String screen) check,
  ) async {
    await check('Today');
    for (final tab in ['Habits', 'Calendar', 'Settings']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
      await check(tab);
    }
    await tester.tap(find.text('Habits').last);
    await settle(tester);
    await tapVisible(tester, find.text('Gym').first);
    await settle(tester);
    await check('Habit editor');
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await tapVisible(tester, find.text('30 days of Read 10 pages'));
    await settle(tester);
    await check('Challenges');
  }

  for (final theme in [ThemePreference.light, ThemePreference.dark]) {
    testWidgets('accessibility guidelines (${theme.name})', (tester) async {
      await seed(tester, theme: theme);
      await pumpApp(tester, db, clock: clock);
      await visitAll(tester, (screen) => checkGuidelines(tester, screen));
    });
  }

  testWidgets('layouts hold at 200% text size', (tester) async {
    await seed(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, db, clock: clock);
    await visitAll(tester, (screen) async {
      expect(tester.takeException(), isNull, reason: '$screen overflowed');
    });
  });
}
