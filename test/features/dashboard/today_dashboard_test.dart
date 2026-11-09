import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/dashboard/application/today_providers.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  const monday = LocalDay(2026, 11, 9);
  DateTime clock() => DateTime(2026, 11, 9, 9);

  group('DayProgress', () {
    TodayEntry entry(CompletionStatus? status) =>
        TodayEntry(habit: habitFixture(), status: status);

    test('counts done over scheduled, excluding rest days', () {
      final p = DayProgress.of([
        entry(CompletionStatus.done),
        entry(null),
        entry(CompletionStatus.skipped),
      ]);
      expect(p, const DayProgress(done: 1, total: 2));
      expect(p.fraction, 0.5);
      expect(p.isComplete, isFalse);
    });

    test('complete when every non-rest habit is done', () {
      final p = DayProgress.of([
        entry(CompletionStatus.done),
        entry(CompletionStatus.skipped),
      ]);
      expect(p.isComplete, isTrue);
    });

    test('no scheduled habits is zero, not complete', () {
      final p = DayProgress.of(const []);
      expect(p.fraction, 0);
      expect(p.isComplete, isFalse);
    });
  });

  group('Today screen', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    Future<String> seed(
      WidgetTester tester,
      String name, {
      HabitFrequency frequency = HabitFrequency.daily,
      List<int> days = const [],
    }) async => (await tester.runAsync(
      () => HabitRepository(db).createHabit(
        HabitDraft(
          name: name,
          frequency: frequency,
          targetDays: days,
          startDate: const LocalDay(2026, 11, 1),
        ),
      ),
    ))!;

    testWidgets('lists today\'s scheduled habits with progress', (
      tester,
    ) async {
      final read = await seed(tester, 'Read');
      await seed(tester, 'Gym', frequency: HabitFrequency.weekdays, days: [1]);
      await seed(tester, 'Swim', frequency: HabitFrequency.weekdays, days: [2]);
      await tester.runAsync(() => CompletionRepository(db).mark(read, monday));

      await pumpApp(tester, db, clock: clock);

      expect(find.text('Monday, November 9'), findsOneWidget);
      expect(find.text('1 of 2 done'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('Swim'), findsNothing);
    });

    testWidgets('shows a rest message when nothing is scheduled today', (
      tester,
    ) async {
      await seed(tester, 'Swim', frequency: HabitFrequency.weekdays, days: [2]);
      await pumpApp(tester, db, clock: clock);

      expect(find.text('Nothing scheduled today'), findsOneWidget);
      expect(find.text('0 of 0 done'), findsOneWidget);
    });

    testWidgets('empty state offers to create the first habit', (tester) async {
      await pumpApp(tester, db, clock: clock);
      expect(find.text('No habits yet'), findsOneWidget);

      await tester.tap(find.text('Create a habit'));
      await tester.pumpAndSettle();
      expect(find.text('New habit'), findsWidgets);
    });

    testWidgets('celebrates when everything is done', (tester) async {
      final id = await seed(tester, 'Read');
      await tester.runAsync(() => CompletionRepository(db).mark(id, monday));
      await pumpApp(tester, db, clock: clock);

      expect(find.text('1 of 1 done'), findsOneWidget);
      expect(find.text('All done for today. Well done!'), findsOneWidget);
    });
  });
}
