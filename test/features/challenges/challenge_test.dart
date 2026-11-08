import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/challenges/data/challenge_repository.dart';
import 'package:habitflow/features/challenges/domain/challenge_progress.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  const today = LocalDay(2026, 11, 20);
  DateTime clock() => DateTime(2026, 11, 20, 9);

  group('challengeProgress', () {
    Challenge challenge({String start = '2026-11-10', int days = 30}) =>
        Challenge(
          id: 'c1',
          title: '30 days of Read',
          habitId: 'h1',
          durationDays: days,
          startDate: start,
          status: ChallengeStatus.active,
          createdAt: DateTime(2026, 11, 10),
          updatedAt: DateTime(2026, 11, 10),
        );

    Map<String, CompletionStatus> done(Iterable<int> novDays) => {
      for (final d in novDays) LocalDay(2026, 11, d).key: CompletionStatus.done,
    };

    test('counts completed days since the start; misses never reset', () {
      // Done 10, 11, (missed 12–14), 15, 16.
      final p = challengeProgress(
        challenge: challenge(),
        habitHistory: done([10, 11, 15, 16]),
        today: today,
      );
      expect(p.completedDays, 4);
      expect(p.dayNumber, 11);
      expect(p.remaining, 26);
      expect(p.isComplete, isFalse);
    });

    test('completions before the start and rest days do not count', () {
      final history = {
        ...done([5, 6, 12]),
        const LocalDay(2026, 11, 13).key: CompletionStatus.skipped,
      };
      final p = challengeProgress(
        challenge: challenge(),
        habitHistory: history,
        today: today,
      );
      expect(p.completedDays, 1);
    });

    test('complete on the goal-th completed day', () {
      final p = challengeProgress(
        challenge: challenge(start: '2026-11-01', days: 3),
        habitHistory: done([1, 2, 3]),
        today: today,
      );
      expect(p.isComplete, isTrue);
      expect(p.fraction, 1.0);
    });
  });

  group('challenge screens', () {
    late AppDatabase db;
    late String habitId;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    Future<void> seedHabit(
      WidgetTester tester, {
      List<int> doneDays = const [],
    }) => tester.runAsync(() async {
      habitId = await HabitRepository(db).createHabit(
        const HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 10, 1),
        ),
      );
      for (final d in doneDays) {
        await CompletionRepository(db).mark(habitId, LocalDay(2026, 11, d));
      }
    });

    Future<List<Challenge>> challenges(WidgetTester tester) async =>
        (await tester.runAsync(() => db.select(db.challenges).get()))!;

    testWidgets('start a free challenge from Today', (tester) async {
      await seedHabit(tester);
      await pumpApp(tester, db, clock: clock);

      await tester.tap(find.text('Try a free 30-day challenge'));
      await settle(tester);
      expect(find.text('Free'), findsOneWidget);

      await tester.tap(find.text('Start a challenge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read').last);
      await settle(tester);

      expect(find.text('30 days of Read'), findsOneWidget);
      expect(find.text('0 of 30 days'), findsOneWidget);
      final stored = (await challenges(tester)).single;
      expect(stored.startDate, today.key);
      expect(stored.habitId, habitId);

      // Today shows the challenge strip and counts a tick immediately.
      await tester.pageBack();
      await settle(tester);
      expect(find.text('0/30'), findsOneWidget);
      await tester.tap(find.byKey(const Key('complete-Read')));
      await settle(tester);
      expect(find.text('1/30'), findsOneWidget);
    });

    testWidgets('restart begins again from today', (tester) async {
      await seedHabit(tester, doneDays: [18, 19]);
      await tester.runAsync(
        () => ChallengeRepository(db).create(
          title: '30 days of Read',
          habitId: habitId,
          startDate: const LocalDay(2026, 11, 18),
        ),
      );
      await pumpApp(tester, db, clock: clock);
      await tester.tap(find.text('30 days of Read'));
      await settle(tester);
      expect(find.text('2 of 30 days'), findsOneWidget);

      await tester.tap(find.byTooltip('Challenge options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
      await settle(tester);

      expect(find.text('0 of 30 days'), findsOneWidget);
      expect((await challenges(tester)).single.startDate, today.key);
    });

    testWidgets('ending keeps it in history', (tester) async {
      await seedHabit(tester, doneDays: [19]);
      await tester.runAsync(
        () => ChallengeRepository(db).create(
          title: '30 days of Read',
          habitId: habitId,
          startDate: const LocalDay(2026, 11, 18),
        ),
      );
      await pumpApp(tester, db, clock: clock);
      await tester.tap(find.text('30 days of Read'));
      await settle(tester);

      await tester.tap(find.byTooltip('Challenge options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End challenge'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End'));
      await settle(tester);

      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('1 of 30 days'), findsOneWidget);
      expect(
        (await challenges(tester)).single.status,
        ChallengeStatus.abandoned,
      );
    });

    testWidgets('reaching the goal completes the challenge, for free', (
      tester,
    ) async {
      await seedHabit(tester, doneDays: [18, 19]);
      await tester.runAsync(
        () => ChallengeRepository(db).create(
          title: '3 days of Read',
          habitId: habitId,
          startDate: const LocalDay(2026, 11, 18),
          durationDays: 3,
        ),
      );
      await pumpApp(tester, db, clock: clock);

      await tester.tap(find.byKey(const Key('complete-Read')));
      await settle(tester);

      final stored = (await challenges(tester)).single;
      expect(stored.status, ChallengeStatus.completed);
      expect(stored.completedAt, isNotNull);

      await tester.tap(find.text('Try a free 30-day challenge'));
      await settle(tester);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('pausing a challenge pauses its habit', (tester) async {
      await seedHabit(tester);
      await tester.runAsync(
        () => ChallengeRepository(
          db,
        ).create(title: '30 days of Read', habitId: habitId, startDate: today),
      );
      await pumpApp(tester, db, clock: clock);
      await tester.tap(find.text('30 days of Read'));
      await settle(tester);

      await tester.tap(find.byTooltip('Challenge options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 week'));
      await settle(tester);

      expect(find.text('Paused until Thu, Nov 26'), findsOneWidget);
      final habit = (await tester.runAsync(
        () => HabitRepository(db).getHabit(habitId),
      ))!;
      expect(habit.pausedUntil, '2026-11-26');
    });
  });
}
