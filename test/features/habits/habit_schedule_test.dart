import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/domain/habit_schedule.dart';

import '../../helpers/fixtures.dart';

void main() {
  // 2026-11-09 is a Monday.
  const mon = LocalDay(2026, 11, 9);
  final week = List.generate(7, mon.addDays);

  group('HabitSchedule.isDueOn', () {
    test('daily is due every day', () {
      const s = HabitSchedule(frequency: HabitFrequency.daily);
      expect(week.every(s.isDueOn), isTrue);
    });

    test('weekdays is due only on selected ISO weekdays', () {
      const s = HabitSchedule(
        frequency: HabitFrequency.weekdays,
        weekdays: {1, 3, 5},
      );
      expect(week.where(s.isDueOn).map((d) => d.weekday), [1, 3, 5]);
    });

    test('weekdays handles Sunday (7)', () {
      const s = HabitSchedule(frequency: HabitFrequency.weekdays, weekdays: {7});
      expect(week.where(s.isDueOn).single, const LocalDay(2026, 11, 15));
    });

    test('weekly target is due any day', () {
      const s = HabitSchedule(
        frequency: HabitFrequency.weeklyTarget,
        weeklyTarget: 3,
      );
      expect(week.every(s.isDueOn), isTrue);
    });
  });

  group('HabitScheduler', () {
    test('not scheduled before the start date', () {
      final s = HabitScheduler(habitFixture(startDate: '2026-11-11'), []);
      expect(s.isScheduledOn(mon), isFalse);
      expect(s.isScheduledOn(mon.addDays(1)), isFalse);
      expect(s.isScheduledOn(mon.addDays(2)), isTrue);
    });

    test('not scheduled while paused (inclusive), resumes after', () {
      final s = HabitScheduler(habitFixture(pausedUntil: '2026-11-10'), []);
      expect(s.isScheduledOn(mon), isFalse);
      expect(s.isScheduledOn(mon.addDays(1)), isFalse);
      expect(s.isScheduledOn(mon.addDays(2)), isTrue);
    });

    test('archived habits are never scheduled', () {
      final s = HabitScheduler(habitFixture(isArchived: true), []);
      expect(week.any(s.isScheduledOn), isFalse);
    });

    test('falls back to the habit row when there is no history', () {
      final s = HabitScheduler(
        habitFixture(frequency: HabitFrequency.weekdays, targetDays: '2,4'),
        [],
      );
      expect(week.where(s.isScheduledOn).map((d) => d.weekday), [2, 4]);
    });

    test('past days use the schedule that applied at the time', () {
      // Daily until Wed 11th, then Mon/Fri only.
      final habit = habitFixture(
        frequency: HabitFrequency.weekdays,
        targetDays: '1,5',
      );
      final s = HabitScheduler(habit, [
        scheduleFixture(
          effectiveFrom: '2026-11-11',
          frequency: HabitFrequency.weekdays,
          targetDays: '1,5',
        ),
        scheduleFixture(effectiveFrom: '2026-11-01'),
      ]);

      expect(s.isScheduledOn(mon), isTrue); // daily
      expect(s.isScheduledOn(mon.addDays(1)), isTrue); // Tue, daily
      expect(s.isScheduledOn(mon.addDays(2)), isFalse); // Wed, new rule
      expect(s.isScheduledOn(mon.addDays(4)), isTrue); // Fri
      expect(s.isScheduledOn(mon.addDays(7)), isTrue); // next Mon
    });

    test('the change day itself uses the new schedule', () {
      final s = HabitScheduler(habitFixture(), [
        scheduleFixture(effectiveFrom: '2026-11-01'),
        scheduleFixture(
          effectiveFrom: '2026-11-09',
          frequency: HabitFrequency.weekdays,
          targetDays: '2',
        ),
      ]);
      expect(s.isScheduledOn(mon), isFalse);
      expect(s.isScheduledOn(mon.addDays(-1)), isTrue);
    });
  });

  group('describeSchedule', () {
    test('summaries', () {
      expect(
        describeSchedule(const HabitSchedule(frequency: HabitFrequency.daily)),
        'Every day',
      );
      expect(
        describeSchedule(
          const HabitSchedule(
            frequency: HabitFrequency.weekdays,
            weekdays: {1, 2, 3, 4, 5},
          ),
        ),
        'Weekdays',
      );
      expect(
        describeSchedule(
          const HabitSchedule(
            frequency: HabitFrequency.weekdays,
            weekdays: {6, 7},
          ),
        ),
        'Weekends',
      );
      expect(
        describeSchedule(
          const HabitSchedule(
            frequency: HabitFrequency.weekdays,
            weekdays: {5, 1, 3},
          ),
        ),
        'Mon, Wed, Fri',
      );
      expect(
        describeSchedule(
          const HabitSchedule(
            frequency: HabitFrequency.weeklyTarget,
            weeklyTarget: 3,
          ),
        ),
        '3× per week',
      );
    });
  });
}
