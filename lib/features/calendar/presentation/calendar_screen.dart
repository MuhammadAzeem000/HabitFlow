import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

/// Monthly completion history — built in Phase 4.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: const EmptyState(
        icon: Icons.calendar_month,
        title: 'Your history',
        message: 'Monthly completion history will appear here.',
      ),
    );
  }
}
