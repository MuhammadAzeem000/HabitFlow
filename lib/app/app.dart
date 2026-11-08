import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utilities/time_format.dart';
import '../features/settings/application/settings_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class HabitFlowApp extends ConsumerWidget {
  const HabitFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsControllerProvider.select((s) => s.theme));
    final timeFormat = ref.watch(
      settingsControllerProvider.select((s) => s.timeFormat),
    );
    return MaterialApp.router(
      title: 'HabitFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => TimeFormatScope(
        preference: timeFormat,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
