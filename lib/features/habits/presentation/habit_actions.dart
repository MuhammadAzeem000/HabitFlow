import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../../core/utilities/local_day.dart';

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

/// The pause end date for [habit] if it is paused on [today] (or a pause is
/// scheduled to cover today or later), otherwise null.
LocalDay? activePauseEnd(Habit habit, LocalDay today) {
  final until = habit.pausedUntil == null
      ? null
      : LocalDay.parse(habit.pausedUntil!);
  return until != null && !until.isBefore(today) ? until : null;
}

/// "Paused until Mon, Nov 16".
String pausedUntilLabel(LocalDay until) =>
    'Paused until ${DateFormat.MMMEd().format(until.startOfDay)}';

/// Lets the user choose how long to pause [habit], then pauses it with an
/// undo. Paused days never count as misses. Returns true if paused.
Future<bool> choosePauseAndApply(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
) async {
  final today = ref.read(currentDayProvider);
  // If today is already done, keep it: the pause starts tomorrow.
  final doneToday =
      await ref.read(completionRepositoryProvider).statusOn(habit.id, today) ==
      CompletionStatus.done;
  if (!context.mounted) return false;
  final start = doneToday ? today.addDays(1) : today;
  final until = await showModalBottomSheet<LocalDay>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              'Pause “${habit.name}”',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Paused days don’t count against your streak or consistency.',
            ),
          ),
          for (final (label, days) in const [
            ('3 days', 3),
            ('1 week', 7),
            ('2 weeks', 14),
          ])
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: Text(label),
              onTap: () => Navigator.pop(context, start.addDays(days - 1)),
            ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Until a date…'),
            onTap: () async {
              final navigator = Navigator.of(context);
              final picked = await showDatePicker(
                context: context,
                initialDate: start.addDays(6).startOfDay,
                firstDate: start.startOfDay,
                lastDate: today.addDays(365).startOfDay,
                helpText: 'Pause through',
              );
              if (picked != null) {
                navigator.pop(LocalDay.fromDateTime(picked));
              }
            },
          ),
        ],
      ),
    ),
  );
  if (until == null || !context.mounted) return false;

  final repo = ref.read(habitRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  await repo.pause(habit.id, from: start, until: until);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          doneToday
              ? '“${habit.name}” is paused from tomorrow until '
                    '${DateFormat.MMMEd().format(until.startOfDay)}. '
                    'Today stays done.'
              : '“${habit.name}” is paused until '
                    '${DateFormat.MMMEd().format(until.startOfDay)}.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.restorePause(
            habit.id,
            from: habit.pausedFrom,
            until: habit.pausedUntil,
          ),
        ),
      ),
    );
  return true;
}

/// Resumes a paused habit from today.
Future<void> resumeHabit(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final today = ref.read(currentDayProvider);
  await ref.read(habitRepositoryProvider).resume(habit.id, today: today);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('“${habit.name}” resumed.')));
}
