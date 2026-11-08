import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/stats_providers.dart';
import '../domain/streak.dart';

/// Current streak, best streak and this week's consistency for one habit,
/// shown on its edit screen.
class HabitStatsSummary extends ConsumerWidget {
  const HabitStatsSummary({required this.habitId, super.key});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streaksProvider).value?[habitId];
    final week = ref.watch(weeklyStatsProvider).value?[habitId];
    if (streak == null) return const SizedBox.shrink();
    final goal = week?.goalProgress;
    final thisWeek = goal != null
        ? '${goal.done} of ${goal.goal}'
        : week?.consistency.percentLabel ?? '—';
    final unit = streak.unit == StreakUnit.days ? 'days' : 'weeks';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.local_fire_department_outlined,
              label: 'Current streak',
              value: '${streak.current} $unit',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.emoji_events_outlined,
              label: 'Best streak',
              value: '${streak.longest} $unit',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.insights,
              label: 'This week',
              value: thisWeek,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.titleLarge),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
