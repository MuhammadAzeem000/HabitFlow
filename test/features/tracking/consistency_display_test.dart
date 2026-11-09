import 'package:flutter/widgets.dart';
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
  const monday = LocalDay(2026, 11, 9);
  DateTime thursday() => DateTime(2026, 11, 12, 9);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> seed(
    WidgetTester tester,
    String name,
    List<int> doneDays, {
    HabitFrequency frequency = HabitFrequency.daily,
    int? weeklyTarget,
  }) async {
    await tester.runAsync(() async {
      final id = await HabitRepository(db).createHabit(
        HabitDraft(
          name: name,
          frequency: frequency,
          weeklyTarget: weeklyTarget,
          startDate: const LocalDay(2026, 11, 1),
        ),
      );
      for (final d in doneDays) {
        await CompletionRepository(db).mark(id, monday.addDays(d));
      }
    });
  }

  testWidgets('header shows weekly consistency across habits', (tester) async {
    // Read: Mon, Tue, Wed done (3/3). Walk: Mon done, Tue+Wed missed (1/3).
    await seed(tester, 'Read', [0, 1, 2]);
    await seed(tester, 'Walk', [0]);
    await pumpApp(tester, db, clock: thursday);

    // 4 of 6 scheduled so far (today is still open).
    expect(find.text('This week: 67% consistent'), findsOneWidget);
  });

  testWidgets('weekly-goal habits show progress toward the goal', (
    tester,
  ) async {
    await seed(
      tester,
      'Swim',
      [0, 2],
      frequency: HabitFrequency.weeklyTarget,
      weeklyTarget: 3,
    );
    await pumpApp(tester, db, clock: thursday);
    expect(find.text('2 of 3 this week'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-Swim')));
    // The tick itself lands on the next frame (see instant_completion_test);
    // statistics derived from it follow within one more frame.
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Goal met this week'), findsOneWidget);
  });

  testWidgets('edit screen shows this week\'s consistency', (tester) async {
    await seed(tester, 'Read', [0, 2]); // Tue missed → 2 of 3
    await pumpApp(tester, db, clock: thursday);

    await tester.tap(find.text('Read'));
    await settle(tester);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
  });
}
