// Enums persisted by name via Drift `textEnum`.
//
// IMPORTANT: values are stored as their `.name`. Renaming a value is a data
// migration; adding new values is safe.

/// How a habit is scheduled.
enum HabitFrequency {
  /// Every day.
  daily,

  /// Only on the ISO weekdays listed in `target_days`.
  weekdays,

  /// A number of completions per week (`weekly_target`), any days.
  weeklyTarget,
}

/// State of a single habit on a single day.
enum CompletionStatus {
  /// The habit was completed.
  done,

  /// A planned rest day: not a completion, never counted as a miss.
  skipped,
}

enum ChallengeStatus { active, paused, completed, abandoned }

enum TimeFormatPreference { system, h12, h24 }

enum ThemePreference { system, light, dark }
