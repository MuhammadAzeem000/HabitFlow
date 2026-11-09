import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  DateTime clock() => DateTime(2026, 11, 9, 9); // Monday

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<List<Habit>> allHabits(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.habits).get()))!;

  Future<String> seed(WidgetTester tester, String name) async =>
      (await tester.runAsync(
        () => HabitRepository(db).createHabit(
          HabitDraft(
            name: name,
            frequency: HabitFrequency.daily,
            startDate: const LocalDay(2026, 11, 1),
          ),
        ),
      ))!;

  Future<void> openHabitsTab(WidgetTester tester) async {
    await pumpApp(tester, db, clock: clock);
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a habit with icon, colour and weekday schedule', (
    tester,
  ) async {
    await openHabitsTab(tester);
    await tester.tap(find.text('New habit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('habit-name')), 'Gym');
    await tapVisible(tester, find.byTooltip('fitness'));
    await tapVisible(tester, find.text('Some days'));
    await tester.pumpAndSettle();
    // Default weekdays are Mon–Fri; drop Tue and Thu.
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Tue'));
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Thu'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Mon, Wed, Fri'), findsOneWidget);
    final habit = (await allHabits(tester)).single;
    expect(habit.icon, 'fitness');
    expect(habit.frequency, HabitFrequency.weekdays);
    expect(habit.targetDays, '1,3,5');
    expect(habit.startDate, '2026-11-09');
  });

  testWidgets('shows validation errors and does not save', (tester) async {
    await openHabitsTab(tester);
    await tester.tap(find.text('New habit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Give your habit a name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('habit-name')), 'Gym');
    await tapVisible(tester, find.text('Some days'));
    await tester.pumpAndSettle();
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      await tapVisible(tester, find.widgetWithText(FilterChip, d));
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pick at least one day.'), findsOneWidget);
    expect(await allHabits(tester), isEmpty);
  });

  testWidgets('edits an existing habit', (tester) async {
    await seed(tester, 'Read');
    await openHabitsTab(tester);

    await tester.tap(find.text('Read'));
    await settle(tester);
    expect(find.text('Edit habit'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('habit-name')),
      'Read 20 pages',
    );
    await tapVisible(tester, find.text('Weekly goal'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Fewer'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Read 20 pages'), findsOneWidget);
    expect(find.text('2× per week'), findsOneWidget);
  });

  testWidgets('archives with undo, then restores', (tester) async {
    await seed(tester, 'Read');
    await openHabitsTab(tester);

    await tester.tap(find.byTooltip('Habit options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await settle(tester);

    expect(find.textContaining('archived'), findsOneWidget);
    expect(find.text('Archived (1)'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Archived (1)'), findsNothing);
    expect((await allHabits(tester)).single.isArchived, isFalse);
  });

  testWidgets('delete asks for confirmation', (tester) async {
    await seed(tester, 'Read');
    await openHabitsTab(tester);

    await tester.tap(find.byTooltip('Habit options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Read”?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await allHabits(tester), hasLength(1));

    await tester.tap(find.byTooltip('Habit options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(await allHabits(tester), isEmpty);
    expect(find.text('Manage your habits'), findsOneWidget);
  });
}
