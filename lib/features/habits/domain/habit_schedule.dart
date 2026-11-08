import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';
import 'habit_draft.dart';

/// One schedule rule: which days a habit is due.
@immutable
class HabitSchedule {
  const HabitSchedule({
    required this.frequency,
    this.weekdays = const {},
    this.weeklyTarget,
  });

  factory HabitSchedule.fromHabit(Habit habit) => HabitSchedule(
    frequency: habit.frequency,
    weekdays: decodeWeekdays(habit.targetDays).toSet(),
    weeklyTarget: habit.weeklyTarget,
  );

  factory HabitSchedule.fromEntry(HabitScheduleEntry entry) => HabitSchedule(
    frequency: entry.frequency,
    weekdays: decodeWeekdays(entry.targetDays).toSet(),
    weeklyTarget: entry.weeklyTarget,
  );

  final HabitFrequency frequency;

  /// ISO weekdays (1 = Mon … 7 = Sun) for [HabitFrequency.weekdays].
  final Set<int> weekdays;

  /// Completions per week for [HabitFrequency.weeklyTarget].
  final int? weeklyTarget;

  /// Whether the habit can be completed on [day] under this rule.
  ///
  /// Weekly-target habits may be done on any day, so they are due every day
  /// until progress tracking (Phase 3) decides the week's target is met.
  bool isDueOn(LocalDay day) => switch (frequency) {
    HabitFrequency.daily => true,
    HabitFrequency.weekdays => weekdays.contains(day.weekday),
    HabitFrequency.weeklyTarget => true,
  };

  @override
  bool operator ==(Object other) =>
      other is HabitSchedule &&
      other.frequency == frequency &&
      const SetEquality<int>().equals(other.weekdays, weekdays) &&
      other.weeklyTarget == weeklyTarget;

  @override
  int get hashCode => Object.hash(
    frequency,
    const SetEquality<int>().hash(weekdays),
    weeklyTarget,
  );
}

/// Decides whether a habit is scheduled on a given day, honouring its start
/// date, pause and schedule history (so past days keep the schedule that
/// applied at the time).
class HabitScheduler {
  HabitScheduler(this.habit, Iterable<HabitScheduleEntry> history)
    : _history = history.sortedBy((e) => e.effectiveFrom),
      _startDate = LocalDay.parse(habit.startDate),
      _pausedFrom = habit.pausedFrom == null
          ? null
          : LocalDay.parse(habit.pausedFrom!),
      _pausedUntil = habit.pausedUntil == null
          ? null
          : LocalDay.parse(habit.pausedUntil!);

  final Habit habit;
  final List<HabitScheduleEntry> _history;
  final LocalDay _startDate;
  final LocalDay? _pausedFrom;
  final LocalDay? _pausedUntil;

  /// The schedule rule in force on [day].
  HabitSchedule scheduleOn(LocalDay day) {
    if (_history.isEmpty) return HabitSchedule.fromHabit(habit);
    final key = day.key;
    final entry =
        _history.lastWhereOrNull((e) => e.effectiveFrom.compareTo(key) <= 0) ??
        _history.first;
    return HabitSchedule.fromEntry(entry);
  }

  bool hasStartedBy(LocalDay day) => !day.isBefore(_startDate);

  /// Paused from `paused_from` (or the start, for v1 data) through
  /// `paused_until`, inclusive.
  bool isPausedOn(LocalDay day) {
    final until = _pausedUntil;
    if (until == null || day.isAfter(until)) return false;
    final from = _pausedFrom;
    return from == null || !day.isBefore(from);
  }

  /// Whether the habit was due on [day] by its own rules (started, not
  /// paused, and the schedule in force that day includes it), regardless of
  /// whether it is archived now. Used for history and statistics.
  bool isDueOn(LocalDay day) =>
      hasStartedBy(day) && !isPausedOn(day) && scheduleOn(day).isDueOn(day);

  /// Whether the habit should appear on the list for [day]: due and not
  /// archived.
  bool isScheduledOn(LocalDay day) => !habit.isArchived && isDueOn(day);

  LocalDay get startDate => _startDate;
}

/// Short human-readable schedule summary, e.g. "Every day", "Mon, Wed, Fri",
/// "3× per week".
String describeSchedule(HabitSchedule schedule) {
  switch (schedule.frequency) {
    case HabitFrequency.daily:
      return 'Every day';
    case HabitFrequency.weeklyTarget:
      return '${schedule.weeklyTarget ?? 1}× per week';
    case HabitFrequency.weekdays:
      final days = schedule.weekdays.toList()..sort();
      if (days.length == 7) return 'Every day';
      if (const ListEquality<int>().equals(days, [1, 2, 3, 4, 5])) {
        return 'Weekdays';
      }
      if (const ListEquality<int>().equals(days, [6, 7])) return 'Weekends';
      return days.map((d) => weekdayShortNames[d - 1]).join(', ');
  }
}

const weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
