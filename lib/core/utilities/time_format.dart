import 'package:flutter/material.dart';

import '../database/enums.dart';

/// Applies the user's 12/24-hour preference to everything below it by
/// overriding `MediaQuery.alwaysUse24HourFormat`. With
/// [TimeFormatPreference.system] the device setting passes through
/// untouched, so time pickers and [formatTime] follow Android.
class TimeFormatScope extends StatelessWidget {
  const TimeFormatScope({
    required this.preference,
    required this.child,
    super.key,
  });

  final TimeFormatPreference preference;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final use24h = switch (preference) {
      TimeFormatPreference.system => null,
      TimeFormatPreference.h12 => false,
      TimeFormatPreference.h24 => true,
    };
    if (use24h == null) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
      child: child,
    );
  }
}

/// Formats [time] using the effective 12/24-hour setting.
String formatTime(BuildContext context, TimeOfDay time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Parses a stored `HH:mm` time.
TimeOfDay? parseStoredTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return TimeOfDay(hour: h, minute: m);
}

/// Stores [time] as `HH:mm` (24-hour, locale-independent).
String toStoredTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
