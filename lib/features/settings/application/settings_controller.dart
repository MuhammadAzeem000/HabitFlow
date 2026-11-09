import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

/// Settings read from the local database before the first frame
/// (overridden in `main.dart`), so the theme is right on first paint.
final initialSettingsProvider = Provider<UserSetting>(
  (ref) =>
      throw UnimplementedError('initialSettingsProvider must be overridden'),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, UserSetting>(SettingsController.new);

/// Holds current settings; updates apply to the UI immediately and are then
/// written to the database.
class SettingsController extends Notifier<UserSetting> {
  @override
  UserSetting build() => ref.watch(initialSettingsProvider);

  Future<void> setTheme(ThemePreference theme) =>
      _update(state.copyWith(theme: theme));

  Future<void> setTimeFormat(TimeFormatPreference format) =>
      _update(state.copyWith(timeFormat: format));

  Future<void> setNotificationsEnabled({required bool enabled}) =>
      _update(state.copyWith(notificationsEnabled: enabled));

  Future<void> _update(UserSetting next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}
