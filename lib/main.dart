import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_providers.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/data/settings_repository.dart';

/// Local-first launch (HF-003): the only work before the first frame is
/// opening the local database and reading settings. No network, ads,
/// analytics or sign-in run here. Optional background work (reminders,
/// ads) must be started after the first frame and never awaited.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final settings = await SettingsRepository(db).load();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const HabitFlowApp(),
    ),
  );
}
