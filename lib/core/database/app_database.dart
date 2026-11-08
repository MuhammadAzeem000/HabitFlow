import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'enums.dart';
import 'tables.dart';

export 'enums.dart';

part 'app_database.g.dart';

/// The local SQLite database: the single source of truth for the MVP.
@DriftDatabase(
  tables: [Habits, HabitCompletions, HabitSchedules, Challenges, UserSettings],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an [executor] in tests (e.g. an in-memory database).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Opens `habitflow.sqlite` in the app documents directory. On Android,
  /// drift_flutter runs SQLite in a background isolate, so queries never
  /// block the UI thread.
  static QueryExecutor _openConnection() => driftDatabase(name: 'habitflow');

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Add step-by-step migrations here when schemaVersion increases.
      // Generate helpers/tests with: dart run drift_dev make-migrations
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
