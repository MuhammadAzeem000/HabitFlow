import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';
import '../../habits/domain/habit_schedule.dart';
import '../../tracking/domain/consistency.dart';

/// What a single day looked like for one habit (HF-013).
enum DayStatus {
  /// Before the habit started, or not a scheduled day.
  none,

  /// Paused that day.
  paused,

  /// Completed.
  done,

  /// Planned rest day.
  rest,

  /// Scheduled, in the past, not done.
  missed,

  /// Scheduled today (still open) or in the future.
  upcoming,
}

/// Status of [day] for one habit, judged by the schedule in force then.
DayStatus dayStatusFor({
  required HabitScheduler scheduler,
  required Map<String, CompletionStatus> statusByDay,
  required LocalDay day,
  required LocalDay today,
}) {
  if (!scheduler.hasStartedBy(day)) return DayStatus.none;
  if (scheduler.isPausedOn(day)) return DayStatus.paused;
  switch (statusByDay[day.key]) {
    case CompletionStatus.done:
      // A completion on an unscheduled day is still shown as done.
      return DayStatus.done;
    case CompletionStatus.skipped:
      return DayStatus.rest;
    case null:
      if (!scheduler.scheduleOn(day).isDueOn(day)) return DayStatus.none;
      return day.isBefore(today) ? DayStatus.missed : DayStatus.upcoming;
  }
}

/// Completed vs scheduled across [schedulers] on [day], using the same
/// rules as weekly consistency: rest and paused days are excluded and an
/// open or future day only counts what is already done.
Consistency dayConsistency({
  required List<HabitScheduler> schedulers,
  required Map<String, Map<String, CompletionStatus>> history,
  required LocalDay day,
  required LocalDay today,
}) {
  var completed = 0;
  var scheduled = 0;
  for (final s in schedulers) {
    final status = dayStatusFor(
      scheduler: s,
      statusByDay: history[s.habit.id] ?? const {},
      day: day,
      today: today,
    );
    switch (status) {
      case DayStatus.done:
        if (s.isDueOn(day)) {
          completed++;
          scheduled++;
        }
      case DayStatus.missed:
        scheduled++;
      case DayStatus.none ||
          DayStatus.paused ||
          DayStatus.rest ||
          DayStatus.upcoming:
        break;
    }
  }
  return Consistency(completed: completed, scheduled: scheduled);
}

/// Every day of [month] (a day within the month), first to last.
List<LocalDay> daysInMonth(LocalDay month) {
  final first = LocalDay(month.year, month.month, 1);
  final days = <LocalDay>[];
  for (var d = first; d.month == month.month; d = d.addDays(1)) {
    days.add(d);
  }
  return days;
}
