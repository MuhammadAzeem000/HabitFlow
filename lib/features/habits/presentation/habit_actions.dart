import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

/// Archives [habit] and offers an undo. History is always kept.
Future<void> archiveHabit(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
) async {
  final repo = ref.read(habitRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  await repo.setArchived(habit.id, archived: true);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('“${habit.name}” archived. History is kept.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.setArchived(habit.id, archived: false),
        ),
      ),
    );
}

/// Asks for confirmation, then permanently deletes [habit] and its history.
/// Returns true if the habit was deleted.
Future<bool> confirmAndDeleteHabit(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete “${habit.name}”?'),
      content: const Text(
        'This permanently removes the habit and all of its history. '
        'To keep your history, archive it instead.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ref.read(habitRepositoryProvider).deleteHabit(habit.id);
  return true;
}
