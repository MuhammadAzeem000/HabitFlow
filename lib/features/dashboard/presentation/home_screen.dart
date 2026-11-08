import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../habits/application/habit_providers.dart';

/// Today screen. Renders straight from the local database stream; nothing
/// here waits on network, ads, or sign-in. (Full dashboard: Phase 2.)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(activeHabitsProvider);
    final today = DateFormat.MMMMEEEEd().format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(today)),
      body: habits.when(
        // Local reads resolve within a frame or two; avoid a spinner flash.
        loading: () => const SizedBox.shrink(),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load your habits',
          message: '$error',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.spa_outlined,
              title: 'No habits yet',
              message: 'Add your first habit to start building consistency.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                Card(child: ListTile(title: Text(list[i].name))),
          );
        },
      ),
    );
  }
}
