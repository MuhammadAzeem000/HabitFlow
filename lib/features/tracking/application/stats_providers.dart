import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../habits/application/habit_providers.dart';
import '../domain/streak.dart';
import 'completion_controller.dart';

/// Every completion record as `habitId → dayKey → status`. Today's
/// optimistic (not yet stored) taps are applied on top, so statistics update
/// on the same frame as the tap.
final completionHistoryProvider =
    Provider<AsyncValue<Map<String, Map<String, CompletionStatus>>>>((ref) {
      final today = ref.watch(currentDayProvider).key;
      final pending = ref.watch(completionControllerProvider);
      return ref.watch(_storedCompletionsProvider).whenData((rows) {
        final history = <String, Map<String, CompletionStatus>>{};
        for (final row in rows) {
          (history[row.habitId] ??= {})[row.completionDate] = row.status;
        }
        pending.forEach((habitId, p) {
          final days = history[habitId] ??= {};
          if (p.status == null) {
            days.remove(today);
          } else {
            days[today] = p.status!;
          }
        });
        return history;
      });
    });

final _storedCompletionsProvider = StreamProvider<List<HabitCompletion>>(
  (ref) => ref.watch(completionRepositoryProvider).watchAll(),
);

/// Streaks for every active habit, keyed by habit id (HF-010).
final streaksProvider = Provider<AsyncValue<Map<String, Streak>>>((ref) {
  final today = ref.watch(currentDayProvider);
  return combineAsync(
    ref.watch(habitSchedulersProvider),
    ref.watch(completionHistoryProvider),
    (schedulers, history) => {
      for (final s in schedulers)
        s.habit.id: StreakCalculator.calculate(
          scheduler: s,
          statusByDay: history[s.habit.id] ?? const {},
          today: today,
        ),
    },
  );
});
