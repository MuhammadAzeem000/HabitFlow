import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.steps.dart';
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // One step per version. After bumping schemaVersion, run
    // `dart run drift_dev make-migrations` to regenerate the helpers/tests.
    onUpgrade: stepByStep(
      // v2: pauses get a start date, so pausing never rewrites the past.
      from1To2: (m, schema) async {
        await m.addColumn(schema.habits, schema.habits.pausedFrom);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
