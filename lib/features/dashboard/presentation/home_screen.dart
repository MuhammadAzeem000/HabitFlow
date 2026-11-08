import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

/// Today screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: const EmptyState(
        icon: Icons.spa_outlined,
        title: 'No habits yet',
        message: 'Add your first habit to start building consistency.',
      ),
    );
  }
}
