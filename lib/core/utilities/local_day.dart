import 'package:flutter/foundation.dart';

/// A calendar day in the device's local time, with no time-of-day component.
///
/// Habit-day boundaries are defined in device-local time (plan §7). All day
/// arithmetic goes through UTC internally so daylight-saving transitions can
/// never shift a day by an hour and land on the wrong date.
@immutable
class LocalDay implements Comparable<LocalDay> {
  const LocalDay(this.year, this.month, this.day);

  factory LocalDay.fromDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return LocalDay(local.year, local.month, local.day);
  }

  factory LocalDay.today([DateTime Function() clock = DateTime.now]) =>
      LocalDay.fromDateTime(clock());

  /// Parses an ISO 8601 day key (`yyyy-MM-dd`).
  factory LocalDay.parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid day key', key);
    }
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) {
      throw FormatException('Invalid day key', key);
    }
    // DateTime normalises overflow (Feb 30 -> Mar 2); reject such dates.
    final normalised = DateTime.utc(y, m, d);
    final day = LocalDay(normalised.year, normalised.month, normalised.day);
    if (day.key != key) {
      throw FormatException('Invalid day key', key);
    }
    return day;
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// ISO 8601 day key, e.g. `2026-11-08`. Sorts lexicographically by date,
  /// so it can be compared directly in SQL.
  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// ISO weekday: Monday = 1 … Sunday = 7.
  int get weekday => _utc.weekday;

  /// Local midnight at the start of this day.
  DateTime get startOfDay => DateTime(year, month, day);

  LocalDay addDays(int days) {
    final shifted = DateTime.utc(year, month, day + days);
    return LocalDay(shifted.year, shifted.month, shifted.day);
  }

  /// Whole days from [other] to this day (positive when this day is later).
  int differenceInDays(LocalDay other) => _utc.difference(other._utc).inDays;

  bool isBefore(LocalDay other) => compareTo(other) < 0;
  bool isAfter(LocalDay other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDay other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) =>
      other is LocalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => key;
}
