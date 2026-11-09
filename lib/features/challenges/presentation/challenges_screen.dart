import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/presentation/habit_actions.dart';
import '../../habits/presentation/widgets/habit_avatar.dart';
import '../application/challenge_providers.dart';

/// The free 30-day challenge (HF-016).
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(challengeViewsProvider);
    final habits = ref.watch(activeHabitsProvider).value ?? const <Habit>[];
    final active = ref.watch(activeChallengesProvider);
    final eligible = [
      for (final h in habits)
        if (!active.any((v) => v.challenge.habitId == h.id)) h,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('30-day challenge')),
      floatingActionButton: eligible.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _startChallenge(context, ref, eligible),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Start a challenge'),
            ),
      body: views.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load challenges',
          message: '$e',
        ),
        data: (all) {
          final completed = all
              .where((v) => v.challenge.status == ChallengeStatus.completed)
              .toList();
          final ended = all
              .where((v) => v.challenge.status == ChallengeStatus.abandoned)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const _IntroCard(),
              if (habits.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Create a habit first, then turn it into a challenge.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final v in active) ...[
                const SizedBox(height: 12),
                _ActiveChallengeCard(view: v),
              ],
              if (completed.isNotEmpty) ...[
                const _Heading('Completed'),
                for (final v in completed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                    ),
                    title: Text(v.challenge.title),
                    subtitle: Text(
                      v.challenge.completedAt == null
                          ? 'Completed'
                          : 'Completed on '
                                '${DateFormat.yMMMd().format(v.challenge.completedAt!)}',
                    ),
                  ),
              ],
              if (ended.isNotEmpty) ...[
                const _Heading('Ended'),
                for (final v in ended)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(v.challenge.title),
                    subtitle: Text(
                      '${v.progress.completedDays} of ${v.progress.goal} days',
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _startChallenge(
    BuildContext context,
    WidgetRef ref,
    List<Habit> eligible,
  ) async {
    final habit = await showModalBottomSheet<Habit>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Which habit is this challenge for?'),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final h in eligible)
                    ListTile(
                      leading: HabitAvatar(
                        icon: h.icon,
                        color: h.color,
                        size: 36,
                      ),
                      title: Text(h.name),
                      onTap: () => Navigator.pop(context, h),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (habit == null) return;
    await ref
        .read(challengeRepositoryProvider)
        .create(
          title: '30 days of ${habit.name}',
          habitId: habit.id,
          startDate: ref.read(currentDayProvider),
        );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Complete a habit on 30 days',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                const Chip(
                  label: Text('Free'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Missed days never reset your progress, and you can pause any '
              'time. The whole challenge is free, start to finish.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChallengeAction { pause, resume, restart, end }

class _ActiveChallengeCard extends ConsumerWidget {
  const _ActiveChallengeCard({required this.view});

  final ChallengeView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habit = view.habit!;
    final p = view.progress;
    final pausedUntil = activePauseEnd(habit, ref.watch(currentDayProvider));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HabitAvatar(icon: habit.icon, color: habit.color, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.challenge.title,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        pausedUntil != null
                            ? pausedUntilLabel(pausedUntil)
                            : 'Day ${p.dayNumber} · ${p.remaining} to go',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_ChallengeAction>(
                  tooltip: 'Challenge options',
                  onSelected: (a) => _onAction(context, ref, a),
                  itemBuilder: (context) => [
                    if (pausedUntil == null)
                      const PopupMenuItem(
                        value: _ChallengeAction.pause,
                        child: Text('Pause'),
                      )
                    else
                      const PopupMenuItem(
                        value: _ChallengeAction.resume,
                        child: Text('Resume'),
                      ),
                    const PopupMenuItem(
                      value: _ChallengeAction.restart,
                      child: Text('Restart'),
                    ),
                    const PopupMenuItem(
                      value: _ChallengeAction.end,
                      child: Text('End challenge'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: p.fraction,
                  minHeight: 10,
                  // The value must stay numeric (a percentage); the days go
                  // in the label.
                  semanticsLabel:
                      'Challenge progress: ${p.completedDays} of ${p.goal} days',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${p.completedDays} of ${p.goal} days',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _ChallengeAction action,
  ) async {
    final repo = ref.read(challengeRepositoryProvider);
    final habit = view.habit!;
    switch (action) {
      case _ChallengeAction.pause:
        await choosePauseAndApply(context, ref, habit);
      case _ChallengeAction.resume:
        await resumeHabit(context, ref, habit);
      case _ChallengeAction.restart:
        if (await _confirm(
          context,
          'Restart this challenge?',
          'Progress starts again from today. Your habit history is kept.',
          'Restart',
        )) {
          await repo.restart(
            view.challenge.id,
            today: ref.read(currentDayProvider),
          );
        }
      case _ChallengeAction.end:
        if (await _confirm(
          context,
          'End this challenge?',
          'It moves to your history. Your habit keeps going as usual.',
          'End',
        )) {
          await repo.setStatus(view.challenge.id, ChallengeStatus.abandoned);
        }
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
