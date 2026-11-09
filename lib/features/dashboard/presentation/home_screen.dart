import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utilities/current_day.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../challenges/presentation/challenge_strip.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/presentation/habit_actions.dart';
import '../../tracking/application/completion_controller.dart';
import '../../tracking/application/stats_providers.dart';
import '../application/today_providers.dart';
import 'widgets/progress_header.dart';
import 'widgets/today_habit_card.dart';

/// Today screen. Renders straight from local database streams; nothing here
/// waits on network, ads, or sign-in.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(todayEntriesProvider);
    final hasAnyHabit = ref.watch(activeHabitsProvider).value?.isNotEmpty;
    final today = ref.watch(currentDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'New habit',
            onPressed: () => context.push(Routes.newHabit),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: entries.when(
        // Local reads resolve within a frame or two; avoid a spinner flash.
        loading: () => const SizedBox.shrink(),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load your habits',
          message: '$error',
        ),
        data: (list) {
          if (hasAnyHabit == false) {
            return EmptyState(
              icon: Icons.spa_outlined,
              title: 'No habits yet',
              message: 'Add your first habit to start building consistency.',
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.newHabit),
                icon: const Icon(Icons.add),
                label: const Text('Create a habit'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ProgressHeader(
                date: today.startOfDay,
                progress: DayProgress.of(list),
                weekly: ref.watch(overallWeeklyConsistencyProvider),
              ),
              const SizedBox(height: 12),
              const ChallengeStrip(),
              const SizedBox(height: 4),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: EmptyState(
                    icon: Icons.self_improvement,
                    title: 'Nothing scheduled today',
                    message: 'Rest is part of the routine.',
                  ),
                )
              else
                for (final entry in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TodayHabitCard(
                      entry: entry,
                      onToggle: () => _toggle(context, ref, entry),
                      onMore: () => _showDayActions(context, ref, entry),
                      onOpen: () =>
                          context.push(Routes.editHabit(entry.habit.id)),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  /// Rest day, pause and edit actions for a habit on Today (HF-012).
  Future<void> _showDayActions(
    BuildContext context,
    WidgetRef ref,
    TodayEntry entry,
  ) async {
    final habit = entry.habit;
    final action = await showModalBottomSheet<_DayAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isRestDay)
              const ListTile(
                leading: Icon(Icons.undo),
                title: Text('Undo rest day'),
              ).withAction(context, _DayAction.undoRest)
            else
              const ListTile(
                leading: Icon(Icons.self_improvement),
                title: Text('Take a rest day'),
                subtitle: Text('Won’t count against your streak'),
              ).withAction(context, _DayAction.rest),
            const ListTile(
              leading: Icon(Icons.pause_circle_outline),
              title: Text('Pause habit…'),
              subtitle: Text('Take a longer break'),
            ).withAction(context, _DayAction.pause),
            const ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit habit'),
            ).withAction(context, _DayAction.edit),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    final controller = ref.read(completionControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _DayAction.rest:
        final previous = entry.status;
        unawaited(controller.setStatus(habit.id, CompletionStatus.skipped));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Rest day for ${habit.name}. Enjoy it.'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => controller.setStatus(habit.id, previous),
              ),
            ),
          );
      case _DayAction.undoRest:
        unawaited(controller.setStatus(habit.id, null));
      case _DayAction.pause:
        await choosePauseAndApply(context, ref, habit);
      case _DayAction.edit:
        await context.push(Routes.editHabit(habit.id));
    }
  }

  /// Instant, optimistic toggle with an Undo snackbar. Never waits on
  /// anything but the local database.
  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    TodayEntry entry,
  ) async {
    final controller = ref.read(completionControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final habit = entry.habit;
    final previous = entry.status;
    final nowDone = !entry.isDone;

    final write = controller.toggle(habit.id, current: previous);
    if (write == null) return; // accidental double tap — ignored

    unawaited(HapticFeedback.selectionClick());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            nowDone ? '${habit.name} — done' : '${habit.name} — not done',
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.setStatus(habit.id, previous),
          ),
        ),
      );

    try {
      await write;
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Couldn’t save that. Please try again.'),
          ),
        );
    }
  }
}

enum _DayAction { rest, undoRest, pause, edit }

extension on ListTile {
  /// The same tile, closing the sheet with [action] when tapped.
  Widget withAction(BuildContext context, _DayAction action) => ListTile(
    leading: leading,
    title: title,
    subtitle: subtitle,
    onTap: () => Navigator.pop(context, action),
  );
}
