import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';

/// Schedules habit reminders on the device.
abstract class ReminderService {
  /// Prepares the platform plugin. Never awaited on the launch path.
  Future<void> initialize();

  /// Asks for notification permission if needed (Android 13+).
  /// Returns whether notifications are allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

/// Does nothing. Used in tests and on platforms without notifications.
class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}
}

/// Overridden in `main.dart` with [LocalReminderService].
final reminderServiceProvider = Provider<ReminderService>(
  (ref) => const NoopReminderService(),
);

/// Local (on-device) reminders via flutter_local_notifications.
///
/// Uses inexact alarms, so no exact-alarm permission is required; Android
/// may deliver a reminder a few minutes late to save battery.
class LocalReminderService implements ReminderService {
  LocalReminderService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _channel = AndroidNotificationDetails(
    'habit_reminders',
    'Habit reminders',
    channelDescription: 'Optional reminders for the habits you choose.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  @override
  Future<void> initialize() => _ready ??= _init();

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (e) {
      // Fall back to UTC offsets; reminders may shift around DST changes.
      debugPrint('Reminders: could not resolve local timezone: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = _android;
    if (android == null) return true;
    if (await android.areNotificationsEnabled() ?? false) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await initialize();
    await _plugin.cancelAll();
    for (final (i, r) in reminders.indexed) {
      await _plugin.zonedSchedule(
        id: i,
        title: r.title,
        body: r.body,
        payload: r.habitId,
        scheduledDate: tz.TZDateTime.from(r.when, tz.local),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
