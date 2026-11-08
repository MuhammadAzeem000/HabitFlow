import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/utilities/current_day.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../habits/application/habit_providers.dart';
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
              ),
              const SizedBox(height: 16),
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
}
