import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../tracking/domain/consistency.dart';
import '../../application/today_providers.dart';

/// Date, "X of Y done" and a progress ring, with an encouraging line.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    required this.date,
    required this.progress,
    this.weekly,
    super.key,
  });

  final DateTime date;
  final DayProgress progress;

  /// Combined consistency for this week across all habits.
  final Consistency? weekly;

  String get _message {
    if (progress.total == 0) return 'Enjoy your rest day.';
    if (progress.isComplete) return 'All done for today. Well done!';
    if (progress.done == 0) return 'Every check-in counts.';
    return 'Nice progress — keep going.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.MMMMEEEEd().format(date),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.done} of ${progress.total} done',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  if (weekly?.percentLabel case final percent?) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 16,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'This week: $percent consistent',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox.square(
              dimension: 64,
              child: Semantics(
                label: '${(progress.fraction * 100).round()}% complete',
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress.fraction),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: scheme.onPrimaryContainer.withValues(
                      alpha: 0.12,
                    ),
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
