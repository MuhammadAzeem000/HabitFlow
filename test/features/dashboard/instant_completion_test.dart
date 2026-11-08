import 'package:flutter/material.dart';
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
  late String habitId;
  DateTime clock() => DateTime(2026, 11, 9, 9);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> seedAndPump(WidgetTester tester) async {
    habitId = (await tester.runAsync(
      () => HabitRepository(db).createHabit(
        const HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      ),
    ))!;
    await pumpApp(tester, db, clock: clock);
  }

  Future<List<HabitCompletion>> stored(WidgetTester tester) async =>
      (await tester.runAsync(
        () => CompletionRepository(db).getForHabit(habitId),
      ))!;

  testWidgets('one tap completes on the very next frame', (tester) async {
    await seedAndPump(tester);
    expect(find.text('0 of 1 done'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-Read')));
    await tester.pump(); // a single frame — no database round trip

    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(find.text('Read — done'), findsOneWidget);

    await settle(tester);
    expect((await stored(tester)).single.status, CompletionStatus.done);
  });

  testWidgets('undo from the snackbar reverts the completion', (tester) async {
    await seedAndPump(tester);
    await tester.tap(find.byKey(const Key('complete-Read')));
    await settle(tester);

    await tester.tap(find.text('Undo'));
    await settle(tester);

    expect(find.text('0 of 1 done'), findsOneWidget);
    expect(await stored(tester), isEmpty);
  });

  testWidgets('tapping a done habit marks it not done', (tester) async {
    await seedAndPump(tester);
    await tester.tap(find.byKey(const Key('complete-Read')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('complete-Read')));
    await settle(tester);

    expect(find.text('0 of 1 done'), findsOneWidget);
    expect(await stored(tester), isEmpty);
  });

  testWidgets('completion survives an app restart', (tester) async {
    await seedAndPump(tester);
    await tester.tap(find.byKey(const Key('complete-Read')));
    await settle(tester);

    // Rebuild the whole app on the same database.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, db, clock: clock);
    expect(find.text('1 of 1 done'), findsOneWidget);
  });
}
