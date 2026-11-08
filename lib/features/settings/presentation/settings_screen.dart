import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const EmptyState(
        icon: Icons.settings,
        title: 'Appearance',
        message: 'Preferences will appear here.',
      ),
    );
  }
}
