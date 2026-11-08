import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/ads/ad_policy.dart';
import '../../../core/ads/ad_slot.dart';
import '../../../core/database/enums.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/utilities/time_format.dart';
import '../application/settings_controller.dart';

const _sampleTime = TimeOfDay(hour: 21, minute: 30);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemePreference>(
              segments: const [
                ButtonSegment(
                  value: ThemePreference.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemePreference.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemePreference.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {settings.theme},
              onSelectionChanged: (s) => controller.setTheme(s.first),
            ),
          ),
          const _SectionHeader('Reminders'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Habit reminders'),
            subtitle: const Text(
              'Only for habits where you set a reminder time',
            ),
            value: settings.notificationsEnabled,
            onChanged: (on) async {
              await controller.setNotificationsEnabled(enabled: on);
              if (on) {
                await ref.read(reminderServiceProvider).requestPermission();
              }
            },
          ),
          const _SectionHeader('Time format'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<TimeFormatPreference>(
              segments: const [
                ButtonSegment(
                  value: TimeFormatPreference.system,
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: TimeFormatPreference.h12,
                  label: Text('12-hour'),
                ),
                ButtonSegment(
                  value: TimeFormatPreference.h24,
                  label: Text('24-hour'),
                ),
              ],
              selected: {settings.timeFormat},
              onSelectionChanged: (s) => controller.setTimeFormat(s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              settings.timeFormat == TimeFormatPreference.system
                  ? 'Follows your phone’s setting · e.g. '
                        '${formatTime(context, _sampleTime)}'
                  : 'e.g. ${formatTime(context, _sampleTime)}',
              key: const Key('time-format-example'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Free & Plus'),
            subtitle: const Text(
              'What’s free forever, and what may come later',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.plans),
          ),
          const ListTile(
            leading: Icon(Icons.offline_bolt_outlined),
            title: Text('Your data stays on this device'),
            subtitle: Text('HabitFlow works fully offline. No account needed.'),
          ),
          const AdSlot(AdPlacement.settingsFooter),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
