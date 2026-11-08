import 'package:flutter/material.dart';

import '../../domain/habit_appearance.dart';

/// A habit's icon on a tinted circle in its colour.
class HabitAvatar extends StatelessWidget {
  const HabitAvatar({
    required this.icon,
    required this.color,
    this.size = 44,
    super.key,
  });

  final String? icon;
  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = habitColorFor(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(habitIconFor(icon), color: c, size: size * 0.55),
    );
  }
}
