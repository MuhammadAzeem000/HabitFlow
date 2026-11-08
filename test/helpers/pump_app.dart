import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/app/app.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/database/database_providers.dart';
import 'package:habitflow/core/utilities/current_day.dart';
import 'package:habitflow/features/settings/application/settings_controller.dart';
import 'package:habitflow/features/settings/data/settings_repository.dart';

/// Pumps the full app on [db], as `main.dart` does, with an optional clock.
Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  DateTime Function()? clock,
  Duration Function()? monotonicClock,
}) async {
  // A typical phone screen (360×780 dp) instead of the 800×600 default.
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final settings = await tester.runAsync(() => SettingsRepository(db).load());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings!),
        if (clock != null) clockProvider.overrideWithValue(clock),
        monotonicClockProvider.overrideWithValue(
          monotonicClock ?? spacedTapClock(),
        ),
      ],
      child: const HabitFlowApp(),
    ),
  );
  await settle(tester);
}

/// A monotonic clock that advances one second per read, so taps in tests
/// are never mistaken for accidental double taps unless a test opts in.
Duration Function() spacedTapClock() {
  var ticks = 0;
  return () => Duration(seconds: ++ticks);
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Lets database work and streams complete, then settles animations.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
