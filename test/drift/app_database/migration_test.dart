// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // Data-integrity check: rows written by v1 survive the upgrade unchanged.
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    // A v1 habit with a pause keeps every value; the new paused_from column
    // starts empty (meaning "paused from the start", the v1 behaviour).
    const created = '2026-11-01T09:00:00.000';
    final oldHabitsData = <v1.HabitsData>[
      const v1.HabitsData(
        id: 'h1',
        name: 'Read',
        icon: 'book',
        color: 'ff2e7d6b',
        frequency: 'weekdays',
        targetDays: '1,3,5',
        startDate: '2026-11-01',
        orderIndex: 0,
        isArchived: 0,
        pausedUntil: '2026-11-20',
        createdAt: created,
        updatedAt: created,
      ),
    ];
    final expectedNewHabitsData = <v2.HabitsData>[
      const v2.HabitsData(
        id: 'h1',
        name: 'Read',
        icon: 'book',
        color: 'ff2e7d6b',
        frequency: 'weekdays',
        targetDays: '1,3,5',
        startDate: '2026-11-01',
        orderIndex: 0,
        isArchived: 0,
        pausedUntil: '2026-11-20',
        createdAt: created,
        updatedAt: created,
      ),
    ];

    final oldHabitCompletionsData = <v1.HabitCompletionsData>[];
    final expectedNewHabitCompletionsData = <v2.HabitCompletionsData>[];

    final oldHabitSchedulesData = <v1.HabitSchedulesData>[];
    final expectedNewHabitSchedulesData = <v2.HabitSchedulesData>[];

    final oldChallengesData = <v1.ChallengesData>[];
    final expectedNewChallengesData = <v2.ChallengesData>[];

    final oldUserSettingsData = <v1.UserSettingsData>[
      const v1.UserSettingsData(
        id: 'default',
        timeFormat: 'h24',
        theme: 'dark',
        notificationsEnabled: 1,
      ),
    ];
    final expectedNewUserSettingsData = <v2.UserSettingsData>[
      const v2.UserSettingsData(
        id: 'default',
        timeFormat: 'h24',
        theme: 'dark',
        notificationsEnabled: 1,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.habits, oldHabitsData);
        batch.insertAll(oldDb.habitCompletions, oldHabitCompletionsData);
        batch.insertAll(oldDb.habitSchedules, oldHabitSchedulesData);
        batch.insertAll(oldDb.challenges, oldChallengesData);
        batch.insertAll(oldDb.userSettings, oldUserSettingsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewHabitsData, await newDb.select(newDb.habits).get());
        expect(
          expectedNewHabitCompletionsData,
          await newDb.select(newDb.habitCompletions).get(),
        );
        expect(
          expectedNewHabitSchedulesData,
          await newDb.select(newDb.habitSchedules).get(),
        );
        expect(
          expectedNewChallengesData,
          await newDb.select(newDb.challenges).get(),
        );
        expect(
          expectedNewUserSettingsData,
          await newDb.select(newDb.userSettings).get(),
        );
      },
    );
  });
}
