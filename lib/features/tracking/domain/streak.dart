import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';
import '../../habits/domain/habit_schedule.dart';

enum StreakUnit { days, weeks }

/// Current and longest streak for one habit.
@immutable
class Streak {
  const Streak({
    required this.current,
    required this.longest,
    this.unit = StreakUnit.days,
  });

  static const zero = Streak(current: 0, longest: 0);

  final int current;
  final int longest;
  final StreakUnit unit;

  /// e.g. "5-day streak", "3-week streak".
  String get label =>
      '$current-${unit == StreakUnit.days ? 'day' : 'week'} streak';

  @override
  bool operator ==(Object other) =>
      other is Streak &&
      other.current == current &&
      other.longest == longest &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(current, longest, unit);

  @override
  String toString() => 'Streak($current, longest: $longest, ${unit.name})';
}

/// The Monday that starts [day]'s ISO week.
LocalDay weekStartOf(LocalDay day) => day.addDays(1 - day.weekday);

/// Schedule-aware streak rules (HF-010):
///
/// * Only days the habit was **due** count — unscheduled and paused days
///   are neutral, so a Mon/Wed/Fri habit isn't broken by Tuesday.
/// * A **rest day** (`skipped`) is neutral: it neither breaks nor extends.
/// * **Today** is never a miss; it only counts once done.
/// * Completions on days the habit wasn't due are ignored.
/// * **Weekly-goal** habits count streaks in weeks: a week counts when its
///   goal is met; the current week is neutral until then. A week's goal is
///   capped at the number of days the habit was due that week (partial
///   first weeks and pauses don't make a week impossible).
abstract final class StreakCalculator {
  static Streak calculate({
    required HabitScheduler scheduler,
    required Map<String, CompletionStatus> statusByDay,
    required LocalDay today,
  }) {
    if (today.isBefore(scheduler.startDate)) return Streak.zero;
    final weekly =
        scheduler.scheduleOn(today).frequency == HabitFrequency.weeklyTarget;
    return weekly
        ? _weekly(scheduler, statusByDay, today)
        : _daily(scheduler, statusByDay, today);
  }

  static Streak _daily(
    HabitScheduler scheduler,
    Map<String, CompletionStatus> statusByDay,
    LocalDay today,
  ) {
    var current = 0;
    var longest = 0;
    for (
      var day = scheduler.startDate;
      !day.isAfter(today);
      day = day.addDays(1)
    ) {
      if (!scheduler.isDueOn(day)) continue;
      switch (statusByDay[day.key]) {
        case CompletionStatus.done:
          current++;
          longest = math.max(longest, current);
        case CompletionStatus.skipped:
          break; // rest day: neutral
        case null:
          if (day != today) current = 0; // missed (today is still open)
      }
    }
    return Streak(current: current, longest: longest);
  }

  static Streak _weekly(
    HabitScheduler scheduler,
    Map<String, CompletionStatus> statusByDay,
    LocalDay today,
  ) {
    var current = 0;
    var longest = 0;
    final thisWeek = weekStartOf(today);
    for (
      var week = weekStartOf(scheduler.startDate);
      !week.isAfter(thisWeek);
      week = week.addDays(7)
    ) {
      final weekEnd = week.addDays(6);
      final lastCounted = weekEnd.isAfter(today) ? today : weekEnd;

      var dueDays = 0;
      var done = 0;
      for (var d = week; !d.isAfter(lastCounted); d = d.addDays(1)) {
        if (!scheduler.isDueOn(d)) continue;
        dueDays++;
        if (statusByDay[d.key] == CompletionStatus.done) done++;
      }
      final isCurrentWeek = week == thisWeek;
      // The whole week counts toward the goal, even days still ahead.
      final possibleDays = isCurrentWeek
          ? dueDays + _dueDaysAfter(scheduler, today, weekEnd)
          : dueDays;
      final goal = math.min(_goalFor(scheduler, lastCounted), possibleDays);

      if (goal == 0) continue; // fully paused / not started: neutral
      if (done >= goal) {
        current++;
        longest = math.max(longest, current);
      } else if (!isCurrentWeek) {
        current = 0;
      }
    }
    return Streak(current: current, longest: longest, unit: StreakUnit.weeks);
  }

  static int _goalFor(HabitScheduler scheduler, LocalDay day) {
    final schedule = scheduler.scheduleOn(day);
    return schedule.frequency == HabitFrequency.weeklyTarget
        ? (schedule.weeklyTarget ?? 1)
        : 7;
  }

  static int _dueDaysAfter(HabitScheduler s, LocalDay today, LocalDay end) {
    var n = 0;
    for (var d = today.addDays(1); !d.isAfter(end); d = d.addDays(1)) {
      if (s.isDueOn(d)) n++;
    }
    return n;
  }
}
