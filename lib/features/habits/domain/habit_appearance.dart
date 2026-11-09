import 'package:flutter/material.dart';

/// Icons a habit can use, keyed by the stable string stored in `habits.icon`.
///
/// Keys are persisted: never rename one. Add new icons at the end.
const habitIcons = <String, IconData>{
  'check': Icons.check_circle_rounded,
  'water': Icons.water_drop_rounded,
  'book': Icons.menu_book_rounded,
  'run': Icons.directions_run_rounded,
  'walk': Icons.directions_walk_rounded,
  'fitness': Icons.fitness_center_rounded,
  'bike': Icons.directions_bike_rounded,
  'meditate': Icons.self_improvement_rounded,
  'sleep': Icons.bedtime_rounded,
  'food': Icons.restaurant_rounded,
  'fruit': Icons.eco_rounded,
  'pill': Icons.medication_rounded,
  'heart': Icons.favorite_rounded,
  'code': Icons.code_rounded,
  'write': Icons.edit_rounded,
  'language': Icons.translate_rounded,
  'music': Icons.music_note_rounded,
  'brush': Icons.brush_rounded,
  'money': Icons.savings_rounded,
  'clean': Icons.cleaning_services_rounded,
  'phone_off': Icons.phonelink_erase_rounded,
  'sun': Icons.wb_sunny_rounded,
  'pray': Icons.volunteer_activism_rounded,
  'star': Icons.star_rounded,
};

const defaultHabitIcon = 'check';

IconData habitIconFor(String? key) =>
    habitIcons[key] ?? habitIcons[defaultHabitIcon]!;

/// Habit colours as ARGB hex, stored in `habits.color`.
const habitColors = <String>[
  'ff2e7d6b', // teal (brand)
  'ff1e88e5', // blue
  'ff5e35b1', // violet
  'ffd81b60', // pink
  'ffe53935', // red
  'fff4511e', // orange
  'ffffb300', // amber
  'ff7cb342', // green
  'ff00897b', // sea
  'ff6d4c41', // brown
  'ff546e7a', // slate
  'ff8e24aa', // purple
];

const defaultHabitColor = 'ff2e7d6b';

Color habitColorFor(String? hex) {
  final value = int.tryParse(hex ?? '', radix: 16);
  return Color(value ?? int.parse(defaultHabitColor, radix: 16));
}
