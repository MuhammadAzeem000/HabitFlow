import 'package:flutter/material.dart';

import '../../../habits/domain/habit_appearance.dart';
import '../../../habits/domain/habit_schedule.dart';
import '../../../habits/presentation/widgets/habit_avatar.dart';
import '../../../tracking/domain/streak.dart';
import '../../application/today_providers.dart';

/// A habit on the Today list with a large completion button.
class TodayHabitCard extends StatelessWidget {
  const TodayHabitCard({
    required this.entry,
    this.onToggle,
    this.onOpen,
    this.onMore,
    super.key,
  });

  final TodayEntry entry;

  /// Toggles completion. Null renders the button read-only.
  final VoidCallback? onToggle;
  final VoidCallback? onOpen;

  /// Long-press actions (rest day, pause, edit).
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habit = entry.habit;
    final color = habitColorFor(habit.color);
    final goal = entry.week?.goalProgress;
    final schedule = goal == null
        ? describeSchedule(HabitSchedule.fromHabit(habit))
        : goal.done >= goal.goal
        ? 'Goal met this week'
        : '${goal.done} of ${goal.goal} this week';
    final streak = entry.streak;
    final showStreak =
        streak != null &&
        (streak.unit == StreakUnit.weeks
            ? streak.current >= 1
            : streak.current >= 2);
    final subtitle = [
      if (entry.isRestDay) 'Rest day' else schedule,
      if (showStreak) streak.label,
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onMore,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              HabitAvatar(icon: habit.icon, color: habit.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: entry.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: entry.isDone
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _CompletionButton(
                done: entry.isDone,
                color: color,
                label: habit.name,
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionButton extends StatelessWidget {
  const _CompletionButton({
    required this.done,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final bool done;
  final Color color;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: done,
      label: done ? 'Mark $label not done' : 'Mark $label done',
      excludeSemantics: true,
      child: InkResponse(
        key: Key('complete-$label'),
        onTap: onPressed,
        radius: 30,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : Colors.transparent,
              border: Border.all(
                color: done ? color : scheme.outline,
                width: 2.5,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('done'),
                      color: Colors.white,
                      size: 28,
                    )
                  : const SizedBox.shrink(key: ValueKey('todo')),
            ),
          ),
        ),
      ),
    );
  }
}
