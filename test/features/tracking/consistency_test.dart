import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/domain/habit_schedule.dart';
import 'package:habitflow/features/tracking/domain/consistency.dart';

import '../../helpers/fixtures.dart';

void main() {
  const mon = LocalDay(2026, 11, 9);
  LocalDay day(int n) => mon.addDays(n);

  Map<String, CompletionStatus> statuses({
    Iterable<int> done = const [],
    Iterable<int> rest = const [],
  }) => {
    for (final d in done) day(d).key: CompletionStatus.done,
    for (final d in rest) day(d).key: CompletionStatus.skipped,
  };

  Consistency week(
    Habit habit,
    Map<String, CompletionStatus> s, {
    required int today,
  }) => weeklyConsistency(
    scheduler: HabitScheduler(habit, const []),
    statusByDay: s,
    today: day(today),
  );

  final daily = habitFixture(startDate: '2026-11-01');

  group('daily and weekday habits', () {
    test('completed ÷ scheduled up to today', () {
      // Mon–Thu: done Mon, Tue, Thu; missed Wed. Today = Thu.
      final c = week(daily, statuses(done: [0, 1, 3]), today: 3);
      expect(c, const Consistency(completed: 3, scheduled: 4));
      expect(c.percentLabel, '75%');
    });

    test('an open today does not lower consistency', () {
      final c = week(daily, statuses(done: [0, 1]), today: 2);
      expect(c, const Consistency(completed: 2, scheduled: 2));
      expect(c.fraction, 1.0);
    });

    test('rest days are excluded', () {
      final c = week(daily, statuses(done: [0, 2], rest: [1]), today: 2);
      expect(c, const Consistency(completed: 2, scheduled: 2));
    });

    test('unscheduled days are excluded', () {
      final mwf = habitFixture(
        startDate: '2026-11-01',
        frequency: HabitFrequency.weekdays,
        targetDays: '1,3,5',
      );
      // Today = Fri. Done Mon and Fri, missed Wed.
      final c = week(mwf, statuses(done: [0, 4]), today: 4);
      expect(c, const Consistency(completed: 2, scheduled: 3));
    });

    test('paused days are excluded', () {
      final paused = habitFixture(
        startDate: '2026-11-01',
        pausedUntil: day(2).key,
      );
      // Paused through Wed: only Thu (done) and Fri (today, open) remain.
      final c = week(paused, statuses(done: [3]), today: 4);
      expect(c, const Consistency(completed: 1, scheduled: 1));
    });

    test('nothing scheduled yet has no percentage', () {
      final c = week(daily, const {}, today: 0);
      expect(c, Consistency.empty);
      expect(c.fraction, isNull);
      expect(c.percentLabel, isNull);
    });

    test('a habit that started mid-week only counts from its start', () {
      final late = habitFixture(startDate: day(3).key);
      final c = week(late, statuses(done: [3]), today: 4);
      expect(c, const Consistency(completed: 1, scheduled: 1));
    });
  });

  group('weekly goals', () {
    final threePerWeek = habitFixture(
      startDate: '2026-11-01',
      frequency: HabitFrequency.weeklyTarget,
      weeklyTarget: 3,
    );

    test('progress toward the goal', () {
      final c = week(threePerWeek, statuses(done: [0, 2]), today: 3);
      expect(c, const Consistency(completed: 2, scheduled: 3));
    });

    test('extra completions are capped at the goal', () {
      final c = week(threePerWeek, statuses(done: [0, 1, 2, 3]), today: 3);
      expect(c, const Consistency(completed: 3, scheduled: 3));
    });

    test('goal is capped at the days the habit is due this week', () {
      final lateStart = habitFixture(
        startDate: day(5).key, // Saturday
        frequency: HabitFrequency.weeklyTarget,
        weeklyTarget: 3,
      );
      final c = week(lateStart, statuses(done: [5]), today: 5);
      expect(c, const Consistency(completed: 1, scheduled: 2));
    });

    test('weeklyGoalProgress reports uncapped completions', () {
      final p = weeklyGoalProgress(
        scheduler: HabitScheduler(threePerWeek, const []),
        statusByDay: statuses(done: [0, 1, 2, 3]),
        today: day(3),
      );
      expect(p, (done: 4, goal: 3));
      expect(
        weeklyGoalProgress(
          scheduler: HabitScheduler(daily, const []),
          statusByDay: const {},
          today: day(3),
        ),
        isNull,
      );
    });
  });

  test('consistencies add up across habits', () {
    expect(
      const Consistency(completed: 2, scheduled: 3) +
          const Consistency(completed: 1, scheduled: 2),
      const Consistency(completed: 3, scheduled: 5),
    );
  });
}
