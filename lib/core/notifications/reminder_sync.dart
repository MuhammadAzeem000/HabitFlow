import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/application/today_providers.dart';
import '../../features/habits/application/habit_providers.dart';
import '../../features/settings/application/settings_controller.dart';
import '../utilities/current_day.dart';
import 'reminder_planner.dart';
import 'reminder_service.dart';

/// Keeps scheduled reminders in step with habits, today's completions,
/// the day, and the global Reminders setting. Changes are debounced and
/// applied in the background — nothing here blocks the UI.
final reminderSyncProvider = Provider<void>((ref) {
  final service = ref.watch(reminderServiceProvider);
  final enabled = ref.watch(
    settingsControllerProvider.select((s) => s.notificationsEnabled),
  );
  final schedulers = ref.watch(habitSchedulersProvider).value;
  final completions = ref.watch(todayCompletionsProvider).value;
  ref.watch(currentDayProvider);
  if (schedulers == null || completions == null) return;

  final clock = ref.read(clockProvider);
  final timer = Timer(const Duration(milliseconds: 400), () {
    final plan = enabled
        ? planReminders(
            schedulers: schedulers,
            todayStatus: {for (final c in completions) c.habitId: c.status},
            now: clock(),
          )
        : const <PlannedReminder>[];
    service.replaceAll(plan).catchError((Object e) {
      debugPrint('Reminders: could not schedule: $e');
    });
  });
  ref.onDispose(timer.cancel);
});
