import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../domain/habit_schedule.dart';

/// Active habits in user-defined order, streamed from the local database.
final activeHabitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchActiveHabits(),
);

final archivedHabitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchArchivedHabits(),
);

/// Schedule history for every habit, keyed by habit id.
final scheduleHistoryProvider =
    StreamProvider<Map<String, List<HabitScheduleEntry>>>(
      (ref) => ref
          .watch(habitRepositoryProvider)
          .watchAllScheduleHistory()
          .map((entries) => groupBy(entries, (e) => e.habitId)),
    );

/// A [HabitScheduler] per active habit, in user-defined order.
final habitSchedulersProvider = Provider<AsyncValue<List<HabitScheduler>>>((
  ref,
) {
  final habits = ref.watch(activeHabitsProvider);
  final history = ref.watch(scheduleHistoryProvider);
  return combineAsync(
    habits,
    history,
    (habits, history) => [
      for (final h in habits) HabitScheduler(h, history[h.id] ?? const []),
    ],
  );
});

/// Active habits scheduled for today, in user-defined order.
final todaysHabitsProvider = Provider<AsyncValue<List<Habit>>>((ref) {
  final today = ref.watch(currentDayProvider);
  return ref
      .watch(habitSchedulersProvider)
      .whenData(
        (schedulers) => [
          for (final s in schedulers)
            if (s.isScheduledOn(today)) s.habit,
        ],
      );
});

/// Combines two async values: loading until both have data, error if either
/// fails.
AsyncValue<R> combineAsync<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A a, B b) combine,
) {
  if (a case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (b case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (a case AsyncData(value: final av)) {
    if (b case AsyncData(value: final bv)) return AsyncData(combine(av, bv));
  }
  return const AsyncLoading();
}
