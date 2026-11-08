import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/notifications/reminder_planner.dart';
import 'package:habitflow/features/habits/domain/habit_schedule.dart';

import '../../helpers/fixtures.dart';

void main() {
  // Monday 9 Nov 2026, 08:00.
  final now = DateTime(2026, 11, 9, 8);

  List<PlannedReminder> plan(
    List<Habit> habits, {
    Map<String, CompletionStatus> today = const {},
    DateTime? at,
    int days = 7,
  }) => planReminders(
    schedulers: [for (final h in habits) HabitScheduler(h, const [])],
    todayStatus: today,
    now: at ?? now,
    days: days,
  );

  Habit habit({
    String id = 'h1',
    String? reminder = '09:30',
    HabitFrequency frequency = HabitFrequency.daily,
    String? targetDays,
    String? pausedFrom,
    String? pausedUntil,
    String startDate = '2026-11-01',
    bool archived = false,
  }) => habitFixture(
    id: id,
    name: 'Read',
    frequency: frequency,
    targetDays: targetDays,
    pausedFrom: pausedFrom,
    pausedUntil: pausedUntil,
    startDate: startDate,
    isArchived: archived,
  ).copyWith(reminderTime: Value(reminder));

  test('daily habit gets one reminder per day at its time', () {
    final r = plan([habit()]);
    expect(r, hasLength(7));
    expect(r.first.when, DateTime(2026, 11, 9, 9, 30));
    expect(r.last.when, DateTime(2026, 11, 15, 9, 30));
    expect(r.first.title, 'Read');
  });

  test('habits without a reminder time are skipped', () {
    expect(plan([habit(reminder: null)]), isEmpty);
  });

  test('only scheduled weekdays get reminders', () {
    final r = plan([
      habit(frequency: HabitFrequency.weekdays, targetDays: '1,3,5'),
    ]);
    expect(r.map((x) => x.when.weekday), [1, 3, 5]);
  });

  test('a time already passed today is skipped', () {
    final r = plan([habit()], at: DateTime(2026, 11, 9, 10));
    expect(r.first.when, DateTime(2026, 11, 10, 9, 30));
  });

  test('today is skipped once done or a rest day', () {
    for (final status in CompletionStatus.values) {
      final r = plan([habit()], today: {'h1': status});
      expect(r.first.when.day, 10, reason: status.name);
    }
  });

  test('paused days, pre-start days and archived habits get none', () {
    final paused = plan([
      habit(pausedFrom: '2026-11-09', pausedUntil: '2026-11-11'),
    ]);
    expect(paused.first.when.day, 12);

    final later = plan([habit(startDate: '2026-11-13')]);
    expect(later.first.when.day, 13);

    expect(plan([habit(archived: true)]), isEmpty);
  });

  test('reminders from all habits are sorted by time and capped', () {
    final r = plan([
      habit(id: 'a', reminder: '20:00'),
      habit(id: 'b', reminder: '08:30'),
    ], days: 1);
    expect(r.map((x) => x.habitId), ['b', 'a']);

    final many = planReminders(
      schedulers: [
        for (var i = 0; i < 40; i++) HabitScheduler(habit(id: 'h$i'), const []),
      ],
      todayStatus: const {},
      now: now,
    );
    expect(many, hasLength(maxPlannedReminders));
  });
}
