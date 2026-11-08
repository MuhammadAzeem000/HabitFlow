import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late String readId;
  const today = LocalDay(2026, 11, 9);
  DateTime clock() => DateTime(2026, 11, 9, 9);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> seedAndPump(WidgetTester tester) async {
    await tester.runAsync(() async {
      final repo = HabitRepository(db);
      readId = await repo.createHabit(
        const HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      );
      await repo.createHabit(
        const HabitDraft(
          name: 'Walk',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      );
    });
    await pumpApp(tester, db, clock: clock);
  }

  Future<Habit> storedRead(WidgetTester tester) async =>
      (await tester.runAsync(() => HabitRepository(db).getHabit(readId)))!;

  testWidgets('rest day from the Today card is excluded from progress', (
    tester,
  ) async {
    await seedAndPump(tester);
    expect(find.text('0 of 2 done'), findsOneWidget);

    await tester.longPress(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a rest day'));
    await settle(tester);

    expect(find.text('0 of 1 done'), findsOneWidget);
    expect(find.textContaining('Rest day'), findsWidgets);
    final rows = (await tester.runAsync(
      () => CompletionRepository(db).getForHabit(readId),
    ))!;
    expect(rows.single.status, CompletionStatus.skipped);
    expect(rows.single.completionDate, today.key);
  });

  testWidgets('a rest day can be undone from the card menu', (tester) async {
    await seedAndPump(tester);
    await tester.longPress(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a rest day'));
    await settle(tester);

    await tester.longPress(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo rest day'));
    await settle(tester);

    expect(find.text('0 of 2 done'), findsOneWidget);
    final rows = (await tester.runAsync(
      () => CompletionRepository(db).getForHabit(readId),
    ))!;
    expect(rows, isEmpty);
  });

  testWidgets('pausing for a week hides the habit from today onwards', (
    tester,
  ) async {
    await seedAndPump(tester);
    await tester.longPress(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause habit…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 week'));
    await settle(tester);

    expect(find.text('Read'), findsNothing);
    expect(find.text('0 of 1 done'), findsOneWidget);
    final habit = await storedRead(tester);
    expect(habit.pausedFrom, '2026-11-09');
    expect(habit.pausedUntil, '2026-11-15');
  });

  testWidgets('paused habits show on the Habits screen and can resume', (
    tester,
  ) async {
    await seedAndPump(tester);
    await tester.runAsync(
      () =>
          HabitRepository(db)
              .pause(readId, from: today, until: const LocalDay(2026, 11, 15)),
    );
    await settle(tester);

    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
    expect(find.text('Paused until Sun, Nov 15'), findsOneWidget);

    await tester.tap(find.byTooltip('Habit options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await settle(tester);

    // Paused only from today, so resuming today removes the pause.
    final habit = await storedRead(tester);
    expect(habit.pausedUntil, isNull);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('dismissing the pause sheet changes nothing', (tester) async {
    await seedAndPump(tester);
    await tester.longPress(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause habit…'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // tap the scrim
    await settle(tester);

    expect(find.text('Read'), findsOneWidget);
    expect((await storedRead(tester)).pausedUntil, isNull);
  });
}
