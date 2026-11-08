import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('fresh database matches the declared schema', () async {
    // Fails if onCreate/migrations produce a schema that differs from the
    // Drift table definitions. Version-to-version migration tests are
    // generated with `dart run drift_dev make-migrations` from v2 onwards.
    await db.validateDatabaseSchema();
  });

  test('foreign keys are enforced', () async {
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.data.values.single, 1);
  });

  test('schema version is 2', () {
    expect(db.schemaVersion, 2);
  });
}
