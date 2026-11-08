import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';
import '../../habits/domain/habit_schedule.dart';
import 'streak.dart';

/// Completed vs scheduled occurrences for a period (HF-011).
@immutable
class Consistency {
  const Consistency({required this.completed, required this.scheduled});

  static const empty = Consistency(completed: 0, scheduled: 0);

  final int completed;
  final int scheduled;

  /// Null when nothing was scheduled (no basis for a percentage).
  double? get fraction => scheduled == 0 ? null : completed / scheduled;

  /// e.g. "80%", or null when nothing was scheduled.
  String? get percentLabel {
    final f = fraction;
    return f == null ? null : '${(f * 100).round()}%';
  }

  Consistency operator +(Consistency other) => Consistency(
    completed: completed + other.completed,
    scheduled: scheduled + other.scheduled,
  );

  @override
  bool operator ==(Object other) =>
      other is Consistency &&
      other.completed == completed &&
      other.scheduled == scheduled;

  @override
  int get hashCode => Object.hash(completed, scheduled);

  @override
  String toString() => 'Consistency($completed/$scheduled)';
}

/// Weekly consistency = completed scheduled occurrences ÷ scheduled
/// occurrences, for the ISO week containing [today], up to today.
///
/// * Rest days and paused / unscheduled days are excluded from both sides.
/// * Today counts only once it is done, so an open day never lowers it.
/// * Weekly-goal habits: `scheduled` is the week's goal (capped at the days
///   the habit is due this week) and `completed` is completions so far,
///   capped at the goal.
Consistency weeklyConsistency({
  required HabitScheduler scheduler,
  required Map<String, CompletionStatus> statusByDay,
  required LocalDay today,
}) {
  final weekStart = weekStartOf(today);
  final schedule = scheduler.scheduleOn(today);

  if (schedule.frequency == HabitFrequency.weeklyTarget) {
    var dueInWeek = 0;
    var done = 0;
    for (var i = 0; i < 7; i++) {
      final d = weekStart.addDays(i);
      if (!scheduler.isDueOn(d)) continue;
      dueInWeek++;
      if (!d.isAfter(today) && statusByDay[d.key] == CompletionStatus.done) {
        done++;
      }
    }
    final goal = math.min(schedule.weeklyTarget ?? 1, dueInWeek);
    return Consistency(completed: math.min(done, goal), scheduled: goal);
  }

  var completed = 0;
  var scheduled = 0;
  for (var d = weekStart; !d.isAfter(today); d = d.addDays(1)) {
    if (!scheduler.isDueOn(d)) continue;
    switch (statusByDay[d.key]) {
      case CompletionStatus.done:
        completed++;
        scheduled++;
      case CompletionStatus.skipped:
        break; // rest day: excluded
      case null:
        if (d != today) scheduled++; // missed; today is still open
    }
  }
  return Consistency(completed: completed, scheduled: scheduled);
}

/// Completions so far this week for a weekly-goal habit, uncapped (for
/// "2 of 3 this week"). Null for other schedules.
({int done, int goal})? weeklyGoalProgress({
  required HabitScheduler scheduler,
  required Map<String, CompletionStatus> statusByDay,
  required LocalDay today,
}) {
  final schedule = scheduler.scheduleOn(today);
  if (schedule.frequency != HabitFrequency.weeklyTarget) return null;
  final weekStart = weekStartOf(today);
  var done = 0;
  for (var d = weekStart; !d.isAfter(today); d = d.addDays(1)) {
    if (scheduler.isDueOn(d) && statusByDay[d.key] == CompletionStatus.done) {
      done++;
    }
  }
  return (done: done, goal: schedule.weeklyTarget ?? 1);
}
