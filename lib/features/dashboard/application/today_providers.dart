import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../habits/application/habit_providers.dart';
import '../../tracking/application/completion_controller.dart';
import '../../tracking/application/stats_providers.dart';
import '../../tracking/domain/streak.dart';

/// A habit scheduled today, with its state for today (null = not done yet).
@immutable
class TodayEntry {
  const TodayEntry({required this.habit, this.status, this.streak, this.week});

  final Habit habit;
  final CompletionStatus? status;

  /// Null while statistics are still loading.
  final Streak? streak;

  /// This week's figures; null while statistics are still loading.
  final HabitWeekStats? week;

  bool get isDone => status == CompletionStatus.done;
  bool get isRestDay => status == CompletionStatus.skipped;
}

/// Today's progress. Rest days are excluded from the total, so taking a
/// planned break never lowers progress.
@immutable
class DayProgress {
  const DayProgress({required this.done, required this.total});

  factory DayProgress.of(List<TodayEntry> entries) {
    final counted = entries.where((e) => !e.isRestDay);
    return DayProgress(
      done: counted.where((e) => e.isDone).length,
      total: counted.length,
    );
  }

  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
  bool get isComplete => total > 0 && done == total;

  @override
  bool operator ==(Object other) =>
      other is DayProgress && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);
}

/// Completion records for today, streamed from the local database.
final todayCompletionsProvider = StreamProvider<List<HabitCompletion>>((ref) {
  final today = ref.watch(currentDayProvider);
  return ref.watch(completionRepositoryProvider).watchForDay(today);
});

/// Today's scheduled habits with their completion state, in user order.
/// Optimistic (not yet stored) taps take precedence over stored state.
final todayEntriesProvider = Provider<AsyncValue<List<TodayEntry>>>((ref) {
  final pending = ref.watch(completionControllerProvider);
  // Statistics are a bonus: never hold the list back waiting for them.
  final streaks = ref.watch(streaksProvider).value ?? const {};
  final weekStats = ref.watch(weeklyStatsProvider).value ?? const {};
  return combineAsync(
    ref.watch(todaysHabitsProvider),
    ref.watch(todayCompletionsProvider),
    (habits, completions) {
      final byHabit = {for (final c in completions) c.habitId: c.status};
      return [
        for (final h in habits)
          TodayEntry(
            habit: h,
            status: pending.containsKey(h.id)
                ? pending[h.id]!.status
                : byHabit[h.id],
            streak: streaks[h.id],
            week: weekStats[h.id],
          ),
      ];
    },
  );
});

final todayProgressProvider = Provider<AsyncValue<DayProgress>>(
  (ref) => ref.watch(todayEntriesProvider).whenData(DayProgress.of),
);
