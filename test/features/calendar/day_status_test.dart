import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/calendar/domain/day_status.dart';
import 'package:habitflow/features/habits/domain/habit_schedule.dart';
import 'package:habitflow/features/tracking/domain/consistency.dart';

import '../../helpers/fixtures.dart';

void main() {
  const today = LocalDay(2026, 11, 12); // Thursday
  LocalDay nov(int d) => LocalDay(2026, 11, d);

  DayStatus status(
    Habit habit,
    LocalDay day, {
    Map<String, CompletionStatus> s = const {},
  }) => dayStatusFor(
    scheduler: HabitScheduler(habit, const []),
    statusByDay: s,
    day: day,
    today: today,
  );

  final daily = habitFixture(startDate: '2026-11-02');

  test('done, rest, missed and upcoming', () {
    final s = {
      nov(9).key: CompletionStatus.done,
      nov(10).key: CompletionStatus.skipped,
    };
    expect(status(daily, nov(9), s: s), DayStatus.done);
    expect(status(daily, nov(10), s: s), DayStatus.rest);
    expect(status(daily, nov(11), s: s), DayStatus.missed);
    expect(status(daily, today, s: s), DayStatus.upcoming); // still open
    expect(status(daily, nov(20), s: s), DayStatus.upcoming);
  });

  test('before start and unscheduled days are none', () {
    expect(status(daily, nov(1)), DayStatus.none);
    final mwf = habitFixture(
      startDate: '2026-11-02',
      frequency: HabitFrequency.weekdays,
      targetDays: '1,3,5',
    );
    expect(status(mwf, nov(10)), DayStatus.none); // Tuesday
    expect(status(mwf, nov(11)), DayStatus.missed); // Wednesday
  });

  test('paused days are paused, not missed', () {
    final paused = habitFixture(
      startDate: '2026-11-02',
      pausedFrom: '2026-11-09',
      pausedUntil: '2026-11-10',
    );
    expect(status(paused, nov(9)), DayStatus.paused);
    expect(status(paused, nov(11)), DayStatus.missed);
  });

  test('a completion on an unscheduled day still shows as done', () {
    final mwf = habitFixture(
      startDate: '2026-11-02',
      frequency: HabitFrequency.weekdays,
      targetDays: '1,3,5',
    );
    expect(
      status(mwf, nov(10), s: {nov(10).key: CompletionStatus.done}),
      DayStatus.done,
    );
  });

  test('dayConsistency sums habits with consistency rules', () {
    final a = habitFixture(id: 'a', startDate: '2026-11-02');
    final b = habitFixture(id: 'b', startDate: '2026-11-02');
    final c = habitFixture(id: 'c', startDate: '2026-11-02');
    final history = {
      'a': {nov(11).key: CompletionStatus.done},
      'c': {nov(11).key: CompletionStatus.skipped},
    };
    final schedulers = [
      for (final h in [a, b, c]) HabitScheduler(h, const []),
    ];
    // a done, b missed, c rest (excluded).
    expect(
      dayConsistency(
        schedulers: schedulers,
        history: history,
        day: nov(11),
        today: today,
      ),
      const Consistency(completed: 1, scheduled: 2),
    );
    // Future day: nothing counted yet.
    expect(
      dayConsistency(
        schedulers: schedulers,
        history: history,
        day: nov(20),
        today: today,
      ),
      Consistency.empty,
    );
  });

  test('daysInMonth covers the whole month', () {
    expect(daysInMonth(nov(15)), hasLength(30));
    expect(daysInMonth(const LocalDay(2028, 2, 3)), hasLength(29));
    expect(daysInMonth(nov(15)).first, nov(1));
  });
}
