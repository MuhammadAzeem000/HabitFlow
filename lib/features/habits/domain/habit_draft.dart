import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/enums.dart';
import '../../../core/utilities/local_day.dart';

/// User-editable fields of a habit, used for create and edit.
@immutable
class HabitDraft {
  const HabitDraft({
    required this.name,
    required this.frequency,
    required this.startDate,
    this.description,
    this.icon,
    this.color,
    this.targetDays = const [],
    this.weeklyTarget,
    this.reminderTime,
  });

  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final HabitFrequency frequency;

  /// ISO weekdays (1 = Mon … 7 = Sun); used when [frequency] is `weekdays`.
  final List<int> targetDays;

  /// Completions per week; used when [frequency] is `weeklyTarget`.
  final int? weeklyTarget;

  /// Local time `HH:mm`, or null for no reminder.
  final String? reminderTime;
  final LocalDay startDate;

  /// Validation message, or null when the draft can be saved.
  String? validate() {
    if (name.trim().isEmpty) return 'Give your habit a name.';
    if (name.trim().length > 100) return 'Keep the name under 100 characters.';
    switch (frequency) {
      case HabitFrequency.daily:
        return null;
      case HabitFrequency.weekdays:
        if (targetDays.isEmpty) return 'Pick at least one day.';
        if (targetDays.any((d) => d < 1 || d > 7)) return 'Invalid weekday.';
        return null;
      case HabitFrequency.weeklyTarget:
        final target = weeklyTarget;
        if (target == null || target < 1 || target > 7) {
          return 'Choose between 1 and 7 times per week.';
        }
        return null;
    }
  }
}

/// Encodes ISO weekdays as sorted, de-duplicated CSV (`1,3,5`), or null.
String? encodeWeekdays(Iterable<int> days) {
  final sorted = days.toSet().toList()..sort();
  return sorted.isEmpty ? null : sorted.join(',');
}

List<int> decodeWeekdays(String? csv) {
  if (csv == null || csv.isEmpty) return const [];
  return csv.split(',').map(int.parse).toList();
}

/// Whether two schedules differ (used to decide if a new schedule version
/// must be recorded).
bool scheduleChanged({
  required HabitFrequency oldFrequency,
  required String? oldTargetDays,
  required int? oldWeeklyTarget,
  required HabitFrequency newFrequency,
  required List<int> newTargetDays,
  required int? newWeeklyTarget,
}) {
  if (oldFrequency != newFrequency) return true;
  switch (newFrequency) {
    case HabitFrequency.daily:
      return false;
    case HabitFrequency.weekdays:
      return !const ListEquality<int>().equals(
        decodeWeekdays(oldTargetDays),
        decodeWeekdays(encodeWeekdays(newTargetDays)),
      );
    case HabitFrequency.weeklyTarget:
      return oldWeeklyTarget != newWeeklyTarget;
  }
}
