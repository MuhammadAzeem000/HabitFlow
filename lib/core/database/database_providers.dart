import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/challenges/data/challenge_repository.dart';
import '../../features/habits/data/habit_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/tracking/data/completion_repository.dart';
import 'app_database.dart';

/// Overridden in `main.dart` (and in tests) with an opened database.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(appDatabaseProvider)),
);

final completionRepositoryProvider = Provider<CompletionRepository>(
  (ref) => CompletionRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepository(ref.watch(appDatabaseProvider)),
);
