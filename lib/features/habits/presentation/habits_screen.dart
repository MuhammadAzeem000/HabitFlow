import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/habit_providers.dart';
import '../domain/habit_schedule.dart';
import 'habit_actions.dart';
import 'widgets/habit_avatar.dart';

/// Manage habits: create, edit, archive, restore and delete.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeHabitsProvider);
    final archived = ref.watch(archivedHabitsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newHabit),
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
      body: active.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load habits',
          message: '$e',
        ),
        data: (habits) {
          if (habits.isEmpty && archived.isEmpty) {
            return EmptyState(
              icon: Icons.checklist,
              title: 'Manage your habits',
              message: 'Create a habit to start tracking it every day.',
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.newHabit),
                icon: const Icon(Icons.add),
                label: const Text('Create a habit'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final habit in habits) _HabitTile(habit: habit),
              if (archived.isNotEmpty)
                ExpansionTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text('Archived (${archived.length})'),
                  children: [
                    for (final habit in archived)
                      _HabitTile(habit: habit, archived: true),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _HabitAction { edit, archive, restore, delete }

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.habit, this.archived = false});

  final Habit habit;
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Opacity(
        opacity: archived ? 0.5 : 1,
        child: HabitAvatar(icon: habit.icon, color: habit.color),
      ),
      title: Text(habit.name),
      subtitle: Text(describeSchedule(HabitSchedule.fromHabit(habit))),
      onTap: archived ? null : () => context.push(Routes.editHabit(habit.id)),
      trailing: PopupMenuButton<_HabitAction>(
        tooltip: 'Habit options',
        onSelected: (action) async {
          switch (action) {
            case _HabitAction.edit:
              await context.push(Routes.editHabit(habit.id));
            case _HabitAction.archive:
              await archiveHabit(context, ref, habit);
            case _HabitAction.restore:
              await ref
                  .read(habitRepositoryProvider)
                  .setArchived(habit.id, archived: false);
            case _HabitAction.delete:
              await confirmAndDeleteHabit(context, ref, habit);
          }
        },
        itemBuilder: (context) => [
          if (!archived) ...const [
            PopupMenuItem(value: _HabitAction.edit, child: Text('Edit')),
            PopupMenuItem(value: _HabitAction.archive, child: Text('Archive')),
          ] else
            const PopupMenuItem(
              value: _HabitAction.restore,
              child: Text('Restore'),
            ),
          const PopupMenuItem(
            value: _HabitAction.delete,
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}
