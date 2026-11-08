import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habitflow/core/database/app_database.dart';

/// A fresh in-memory database. Streams close synchronously so widget tests
/// don't leave pending timers behind.
AppDatabase createTestDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
