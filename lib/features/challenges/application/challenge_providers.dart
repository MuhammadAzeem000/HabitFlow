import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../habits/application/habit_providers.dart';
import '../../tracking/application/stats_providers.dart';
import '../domain/challenge_progress.dart';

/// A challenge with its habit and progress.
@immutable
class ChallengeView {
  const ChallengeView({
    required this.challenge,
    required this.progress,
    this.habit,
  });

  final Challenge challenge;
  final ChallengeProgress progress;

  /// Null if the habit was deleted.
  final Habit? habit;

  bool get isActive => challenge.status == ChallengeStatus.active;
}

final _challengesProvider = StreamProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).watchAll(),
);

/// Every challenge (newest first) with live progress.
final challengeViewsProvider = Provider<AsyncValue<List<ChallengeView>>>((ref) {
  final today = ref.watch(currentDayProvider);
  final habits = {
    for (final h in ref.watch(activeHabitsProvider).value ?? const <Habit>[])
      h.id: h,
  };
  return combineAsync(
    ref.watch(_challengesProvider),
    ref.watch(completionHistoryProvider),
    (challenges, history) => [
      for (final c in challenges)
        ChallengeView(
          challenge: c,
          habit: habits[c.habitId],
          progress: challengeProgress(
            challenge: c,
            habitHistory: history[c.habitId] ?? const {},
            today: today,
          ),
        ),
    ],
  );
});

/// Active challenges only.
final activeChallengesProvider = Provider<List<ChallengeView>>(
  (ref) => [
    for (final v
        in ref.watch(challengeViewsProvider).value ?? const <ChallengeView>[])
      if (v.isActive && v.habit != null) v,
  ],
);

/// Persists completion the moment an active challenge reaches its goal.
final challengeCompletionSyncProvider = Provider<void>((ref) {
  final repo = ref.watch(challengeRepositoryProvider);
  for (final v in ref.watch(activeChallengesProvider)) {
    if (v.progress.isComplete) {
      repo.markCompleted(v.challenge.id).ignore();
    }
  }
});
