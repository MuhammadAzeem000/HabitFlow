import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/database/database_providers.dart';
import 'package:habitflow/core/utilities/current_day.dart';

/// A [ProviderContainer] wired to [db] with a controllable clock.
ProviderContainer createTestContainer(
  AppDatabase db, {
  DateTime Function()? clock,
}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Reads an `AsyncValue`-returning provider once its data is available.
Future<T> readAsyncData<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  for (var i = 0; i < 50; i++) {
    final value = container.read(provider);
    if (value case AsyncData(:final value)) return value;
    if (value case AsyncError(:final error)) throw error;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('Provider did not produce data');
}
