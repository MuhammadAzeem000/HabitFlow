import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

/// Habit management (create/edit/archive/reorder) — built in Phases 2–3.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      body: const EmptyState(
        icon: Icons.checklist,
        title: 'Manage your habits',
        message: 'Create, edit, reorder and archive habits here.',
      ),
    );
  }
}
