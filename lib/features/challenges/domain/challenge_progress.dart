import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';

/// Progress of a challenge (HF-016).
@immutable
class ChallengeProgress {
  const ChallengeProgress({
    required this.completedDays,
    required this.goal,
    required this.dayNumber,
  });

  /// Days the habit was completed since the challenge started.
  final int completedDays;

  /// Completed days needed (30 for the free challenge).
  final int goal;

  /// Calendar day of the challenge (day 1 = start date).
  final int dayNumber;

  bool get isComplete => completedDays >= goal;
  double get fraction => goal == 0 ? 0 : math.min(1, completedDays / goal);
  int get remaining => math.max(0, goal - completedDays);

  @override
  bool operator ==(Object other) =>
      other is ChallengeProgress &&
      other.completedDays == completedDays &&
      other.goal == goal &&
      other.dayNumber == dayNumber;

  @override
  int get hashCode => Object.hash(completedDays, goal, dayNumber);

  @override
  String toString() =>
      'ChallengeProgress($completedDays/$goal, day $dayNumber)';
}

/// Forgiving challenge rules: progress is the number of days the habit was
/// completed on or after the start date. A missed day never resets it, and
/// the challenge is complete on the [Challenge.durationDays]th completed
/// day. Completions before a restart don't count.
ChallengeProgress challengeProgress({
  required Challenge challenge,
  required Map<String, CompletionStatus> habitHistory,
  required LocalDay today,
}) {
  final start = LocalDay.parse(challenge.startDate);
  final startKey = start.key;
  final todayKey = today.key;
  final completed = habitHistory.entries
      .where(
        (e) =>
            e.value == CompletionStatus.done &&
            e.key.compareTo(startKey) >= 0 &&
            e.key.compareTo(todayKey) <= 0,
      )
      .length;
  return ChallengeProgress(
    completedDays: completed,
    goal: challenge.durationDays,
    dayNumber: math.max(1, today.differenceInDays(start) + 1),
  );
}
