import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/domain/habit_schedule.dart';
import 'package:habitflow/features/tracking/domain/streak.dart';

import '../../helpers/fixtures.dart';

void main() {
  // Mon 2026-11-02 … Sun 2026-11-15 (two ISO weeks).
  const start = LocalDay(2026, 11, 2);
  LocalDay day(int n) => start.addDays(n); // day(0) = Mon 2 Nov

  Map<String, CompletionStatus> done(Iterable<int> days) => {
    for (final d in days) day(d).key: CompletionStatus.done,
  };

  Streak streak(
    Habit habit,
    Map<String, CompletionStatus> statuses, {
    required int today,
    List<HabitScheduleEntry> history = const [],
  }) => StreakCalculator.calculate(
    scheduler: HabitScheduler(habit, history),
    statusByDay: statuses,
    today: day(today),
  );

  final daily = habitFixture(startDate: start.key);

  group('daily habits', () {
    test('counts consecutive completed days', () {
      expect(
        streak(daily, done([0, 1, 2, 3]), today: 3),
        const Streak(current: 4, longest: 4),
      );
    });

    test('a missed day resets the current streak, longest is kept', () {
      // Done Mon–Wed, missed Thu, done Fri–Sat.
      expect(
        streak(daily, done([0, 1, 2, 4, 5]), today: 5),
        const Streak(current: 2, longest: 3),
      );
    });

    test('today not yet done keeps yesterday\'s streak', () {
      expect(
        streak(daily, done([0, 1, 2]), today: 3),
        const Streak(current: 3, longest: 3),
      );
    });

    test('yesterday missed means current streak is 0 until today is done', () {
      expect(streak(daily, done([0, 1]), today: 3).current, 0);
      expect(streak(daily, done([0, 1, 3]), today: 3).current, 1);
    });

    test('no completions is zero', () {
      expect(streak(daily, const {}, today: 5), Streak.zero);
    });

    test('before the start date is zero', () {
      final later = habitFixture(startDate: day(5).key);
      expect(streak(later, const {}, today: 2), Streak.zero);
    });
  });

  group('non-daily habits', () {
    // Mon/Wed/Fri
    final mwf = habitFixture(
      startDate: start.key,
      frequency: HabitFrequency.weekdays,
      targetDays: '1,3,5',
    );

    test('unscheduled days never break the streak', () {
      // Mon, Wed, Fri, next Mon.
      expect(
        streak(mwf, done([0, 2, 4, 7]), today: 8),
        const Streak(current: 4, longest: 4),
      );
    });

    test('a missed scheduled day breaks it', () {
      // Mon, (Wed missed), Fri, Mon.
      expect(
        streak(mwf, done([0, 4, 7]), today: 7),
        const Streak(current: 2, longest: 2),
      );
    });

    test('completions on unscheduled days are ignored', () {
      // Tue and Thu ticked, Wed missed.
      expect(streak(mwf, done([0, 1, 3]), today: 3).current, 0);
    });
  });

  group('rest days and pauses', () {
    test('a rest day is neutral', () {
      final statuses = {
        ...done([0, 1, 3, 4]),
        day(2).key: CompletionStatus.skipped,
      };
      expect(
        streak(daily, statuses, today: 4),
        const Streak(current: 4, longest: 4),
      );
    });

    test('paused days are neutral, and the streak resumes after', () {
      final paused = habitFixture(
        startDate: start.key,
        pausedUntil: day(4).key,
      );
      // Paused through Fri: Mon–Fri are not due, so the missing
      // completions there are not misses. Sat and Sun are done.
      expect(
        streak(paused, done([5, 6]), today: 6),
        const Streak(current: 2, longest: 2),
      );
    });
  });

  test('pausing later never erases earlier misses', () {
    // Missed Wed; paused Sat–Sun; done Mon–Fri before the miss.
    final habit = habitFixture(
      startDate: start.key,
      pausedFrom: day(5).key,
      pausedUntil: day(6).key,
    );
    final s = streak(habit, done([0, 1, 3, 4]), today: 6);
    expect(s, const Streak(current: 2, longest: 2));
  });

  group('schedule edits', () {
    test('past days are judged by the schedule in force at the time', () {
      // Daily until Thu 5 Nov, then Mon/Wed/Fri.
      final habit = habitFixture(
        startDate: start.key,
        frequency: HabitFrequency.weekdays,
        targetDays: '1,3,5',
      );
      final history = [
        scheduleFixture(effectiveFrom: start.key),
        scheduleFixture(
          effectiveFrom: day(3).key,
          frequency: HabitFrequency.weekdays,
          targetDays: '1,3,5',
        ),
      ];
      // Mon–Wed daily done; Thu (now MWF, not due); Fri done; Mon done.
      expect(
        streak(habit, done([0, 1, 2, 4, 7]), today: 7, history: history),
        const Streak(current: 5, longest: 5),
      );
    });
  });

  group('weekly goals', () {
    final threePerWeek = habitFixture(
      startDate: start.key,
      frequency: HabitFrequency.weeklyTarget,
      weeklyTarget: 3,
    );

    test('a week counts once its goal is met', () {
      final s = streak(threePerWeek, done([0, 2, 4]), today: 6);
      expect(s, const Streak(current: 1, longest: 1, unit: StreakUnit.weeks));
      expect(s.label, '1-week streak');
    });

    test('the current week is neutral until the goal is met', () {
      // Week 1 met; week 2 has 1 of 3 so far.
      expect(streak(threePerWeek, done([0, 2, 4, 7]), today: 9).current, 1);
    });

    test('a past week below the goal resets the streak', () {
      // Week 1: 2 of 3; week 2: 3 of 3.
      final s = streak(threePerWeek, done([0, 2, 7, 8, 9]), today: 13);
      expect(s.current, 1);
      expect(s.longest, 1);
    });

    test('a partial first week caps the goal at the days available', () {
      // Starts Saturday: only Sat + Sun that week.
      final lateStart = habitFixture(
        startDate: day(5).key,
        frequency: HabitFrequency.weeklyTarget,
        weeklyTarget: 3,
      );
      expect(streak(lateStart, done([5, 6]), today: 7).current, 1);
    });
  });

  group('date boundaries', () {
    test('streaks run across month and year boundaries', () {
      final nye = habitFixture(startDate: '2026-12-30');
      final statuses = {
        for (final key in ['2026-12-30', '2026-12-31', '2027-01-01'])
          key: CompletionStatus.done,
      };
      expect(
        StreakCalculator.calculate(
          scheduler: HabitScheduler(nye, const []),
          statusByDay: statuses,
          today: const LocalDay(2027, 1, 1),
        ),
        const Streak(current: 3, longest: 3),
      );
    });

    test('weekStartOf returns the ISO Monday', () {
      expect(weekStartOf(const LocalDay(2026, 11, 8)), day(0)); // Sunday
      expect(weekStartOf(day(0)), day(0));
      expect(
        weekStartOf(const LocalDay(2027, 1, 1)),
        const LocalDay(2026, 12, 28),
      );
    });
  });
}
