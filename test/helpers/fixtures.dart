import 'package:habitflow/core/database/app_database.dart';

final _epoch = DateTime(2026, 1, 1);

/// An in-memory [Habit] row for pure-domain tests.
Habit habitFixture({
  String id = 'h1',
  String name = 'Read',
  HabitFrequency frequency = HabitFrequency.daily,
  String? targetDays,
  int? weeklyTarget,
  String startDate = '2026-11-01',
  String? pausedUntil,
  bool isArchived = false,
  int orderIndex = 0,
}) => Habit(
  id: id,
  name: name,
  frequency: frequency,
  targetDays: targetDays,
  weeklyTarget: weeklyTarget,
  startDate: startDate,
  orderIndex: orderIndex,
  isArchived: isArchived,
  pausedUntil: pausedUntil,
  createdAt: _epoch,
  updatedAt: _epoch,
);

HabitScheduleEntry scheduleFixture({
  required String effectiveFrom,
  String habitId = 'h1',
  HabitFrequency frequency = HabitFrequency.daily,
  String? targetDays,
  int? weeklyTarget,
}) => HabitScheduleEntry(
  id: '$habitId-$effectiveFrom',
  habitId: habitId,
  effectiveFrom: effectiveFrom,
  frequency: frequency,
  targetDays: targetDays,
  weeklyTarget: weeklyTarget,
);
