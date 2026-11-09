import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/ads/ad_policy.dart';
import '../../../core/ads/ad_slot.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/habit_providers.dart';
import '../domain/habit_schedule.dart';
import 'habit_actions.dart';
import 'widgets/habit_avatar.dart';

/// Manage habits: create, edit, reorder, archive, restore and delete.
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  /// Order shown immediately after a drag, until the database catches up.
  List<Habit>? _optimisticOrder;

  List<Habit> _visibleOrder(List<Habit> stored) {
    final optimistic = _optimisticOrder;
    if (optimistic == null) return stored;
    final storedIds = stored.map((h) => h.id).toList();
    final optimisticIds = optimistic.map((h) => h.id).toList();
    // Use the stored list once it matches, or if habits were added/removed.
    if (const ListEquality<String>().equals(storedIds, optimisticIds) ||
        !const UnorderedIterableEquality<String>().equals(
          storedIds,
          optimisticIds,
        )) {
      return stored;
    }
    // Keep the optimistic order but with fresh habit data.
    final byId = {for (final h in stored) h.id: h};
    return [for (final id in optimisticIds) byId[id]!];
  }

  /// [to] is the final index (already adjusted for the removed item).
  Future<void> _onReorder(List<Habit> current, int from, int to) async {
    final reordered = [...current];
    final moved = reordered.removeAt(from);
    reordered.insert(to, moved);
    setState(() => _optimisticOrder = reordered);
    HapticFeedback.selectionClick().ignore();
    await ref
        .read(habitRepositoryProvider)
        .reorder(reordered.map((h) => h.id).toList());
  }

  @override
  Widget build(BuildContext context) {
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
        data: (stored) {
          if (stored.isEmpty && archived.isEmpty) {
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
          final habits = _visibleOrder(stored);
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            buildDefaultDragHandles: false,
            itemCount: habits.length,
            onReorderItem: (from, to) => _onReorder(habits, from, to),
            header: habits.length > 1
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Drag to reorder. Today follows this order.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(habit.id),
                index: index,
                child: _HabitTile(
                  habit: habit,
                  dragHandle: ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.drag_handle,
                        key: Key('drag-${habit.name}'),
                        semanticLabel: 'Reorder ${habit.name}',
                      ),
                    ),
                  ),
                ),
              );
            },
            footer: Column(
              children: [
                if (archived.isNotEmpty)
                  ExpansionTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: Text('Archived (${archived.length})'),
                    children: [
                      for (final habit in archived)
                        _HabitTile(habit: habit, archived: true),
                    ],
                  ),
                const AdSlot(AdPlacement.habitsListFooter),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _HabitAction { edit, pause, resume, archive, restore, delete }

class _HabitTile extends ConsumerWidget {
  const _HabitTile({
    required this.habit,
    this.archived = false,
    this.dragHandle,
  });

  final Habit habit;
  final bool archived;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pausedUntil = archived
        ? null
        : activePauseEnd(habit, ref.watch(currentDayProvider));
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        leading: Opacity(
          opacity: archived ? 0.5 : 1,
          child: HabitAvatar(icon: habit.icon, color: habit.color),
        ),
        title: Text(habit.name),
        subtitle: Text(
          pausedUntil != null
              ? pausedUntilLabel(pausedUntil)
              : describeSchedule(HabitSchedule.fromHabit(habit)),
        ),
        onTap: archived ? null : () => context.push(Routes.editHabit(habit.id)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<_HabitAction>(
              tooltip: 'Habit options',
              onSelected: (action) async {
                switch (action) {
                  case _HabitAction.edit:
                    await context.push(Routes.editHabit(habit.id));
                  case _HabitAction.pause:
                    await choosePauseAndApply(context, ref, habit);
                  case _HabitAction.resume:
                    await resumeHabit(context, ref, habit);
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
                if (!archived) ...[
                  const PopupMenuItem(
                    value: _HabitAction.edit,
                    child: Text('Edit'),
                  ),
                  if (pausedUntil == null)
                    const PopupMenuItem(
                      value: _HabitAction.pause,
                      child: Text('Pause'),
                    )
                  else
                    const PopupMenuItem(
                      value: _HabitAction.resume,
                      child: Text('Resume'),
                    ),
                  const PopupMenuItem(
                    value: _HabitAction.archive,
                    child: Text('Archive'),
                  ),
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
            ?dragHandle,
          ],
        ),
      ),
    );
  }
}
