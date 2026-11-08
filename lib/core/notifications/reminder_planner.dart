import 'package:flutter/foundation.dart';

import '../../features/habits/domain/habit_schedule.dart';
import '../database/app_database.dart';
import '../utilities/local_day.dart';
import '../utilities/time_format.dart';

/// One reminder to show at [when] (device-local time).
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.habitId,
    required this.title,
    required this.body,
    required this.when,
  });

  final String habitId;
  final String title;
  final String body;
  final DateTime when;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.habitId == habitId &&
      other.title == title &&
      other.body == body &&
      other.when == when;

  @override
  int get hashCode => Object.hash(habitId, title, body, when);

  @override
  String toString() => 'PlannedReminder($title @ $when)';
}

/// How far ahead reminders are scheduled. The plan is rebuilt whenever the
/// app opens or habits change, so this only matters if the app goes unused.
const reminderWindowDays = 14;

/// Android allows ~500 pending alarms per app; stay well below.
const maxPlannedReminders = 400;

/// Plans one-shot reminders for the next [days] days (HF-015).
///
/// Uses the same [HabitScheduler] rules as the Today list, so reminders
/// never fire on unscheduled, paused or pre-start days. Today's reminder is
/// skipped once the habit is done or marked as a rest day, and reminders
/// whose time has already passed are dropped.
List<PlannedReminder> planReminders({
  required List<HabitScheduler> schedulers,
  required Map<String, CompletionStatus> todayStatus,
  required DateTime now,
  int days = reminderWindowDays,
}) {
  final today = LocalDay.fromDateTime(now);
  final planned = <PlannedReminder>[];
  for (final scheduler in schedulers) {
    final habit = scheduler.habit;
    final time = parseStoredTime(habit.reminderTime);
    if (time == null || habit.isArchived) continue;
    for (var i = 0; i < days; i++) {
      final day = today.addDays(i);
      if (!scheduler.isScheduledOn(day)) continue;
      if (i == 0 && todayStatus.containsKey(habit.id)) continue;
      final when = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (!when.isAfter(now)) continue;
      planned.add(
        PlannedReminder(
          habitId: habit.id,
          title: habit.name,
          body: 'A gentle nudge for today’s check-in.',
          when: when,
        ),
      );
    }
  }
  planned.sort((a, b) => a.when.compareTo(b.when));
  return planned.length > maxPlannedReminders
      ? planned.sublist(0, maxPlannedReminders)
      : planned;
}
