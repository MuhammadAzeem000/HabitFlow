import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ads/ad_policy.dart';
import '../../../core/ads/ad_slot.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utilities/current_day.dart';
import '../../../core/utilities/local_day.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/domain/habit_appearance.dart';
import '../../habits/domain/habit_schedule.dart';
import '../../habits/presentation/widgets/habit_avatar.dart';
import '../../tracking/application/stats_providers.dart';
import '../../tracking/domain/consistency.dart';
import '../domain/day_status.dart';

/// Monthly completion history with scheduled-day context (HF-013).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late LocalDay _month = _firstOf(ref.read(currentDayProvider));
  String? _habitId; // null = all habits

  static LocalDay _firstOf(LocalDay d) => LocalDay(d.year, d.month, 1);

  void _shiftMonth(int delta) => setState(() {
    final m = DateTime(_month.year, _month.month + delta);
    _month = LocalDay(m.year, m.month, 1);
  });

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(currentDayProvider);
    final data = combineAsync(
      ref.watch(habitSchedulersProvider),
      ref.watch(completionHistoryProvider),
      (schedulers, history) => (schedulers: schedulers, history: history),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: data.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load your history',
          message: '$e',
        ),
        data: (d) {
          if (d.schedulers.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month,
              title: 'Your history',
              message: 'Add a habit and your progress will appear here.',
            );
          }
          final selected = d.schedulers
              .where((s) => s.habit.id == _habitId)
              .firstOrNull;
          final shown = selected == null ? d.schedulers : [selected];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _HabitFilter(
                schedulers: d.schedulers,
                selectedId: selected?.habit.id,
                onSelected: (id) => setState(() => _habitId = id),
              ),
              _MonthHeader(
                month: _month,
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              _MonthGrid(
                month: _month,
                today: today,
                schedulers: shown,
                history: d.history,
                single: selected,
                onDayTap: (day) =>
                    _showDay(context, day, today, shown, d.history),
              ),
              _MonthSummary(
                month: _month,
                today: today,
                schedulers: shown,
                history: d.history,
              ),
              _Legend(single: selected != null),
              const AdSlot(AdPlacement.calendarFooter),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDay(
    BuildContext context,
    LocalDay day,
    LocalDay today,
    List<HabitScheduler> schedulers,
    Map<String, Map<String, CompletionStatus>> history,
  ) {
    final rows = [
      for (final s in schedulers)
        (
          habit: s.habit,
          status: dayStatusFor(
            scheduler: s,
            statusByDay: history[s.habit.id] ?? const {},
            day: day,
            today: today,
          ),
        ),
    ].where((r) => r.status != DayStatus.none).toList();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                DateFormat.yMMMMEEEEd().format(day.startOfDay),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text('Nothing was scheduled on this day.'),
              )
            else
              for (final r in rows)
                ListTile(
                  leading: HabitAvatar(
                    icon: r.habit.icon,
                    color: r.habit.color,
                    size: 36,
                  ),
                  title: Text(r.habit.name),
                  trailing: Text(_statusLabel(r.status)),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(DayStatus s) => switch (s) {
  DayStatus.done => 'Done',
  DayStatus.rest => 'Rest day',
  DayStatus.missed => 'Not done',
  DayStatus.paused => 'Paused',
  DayStatus.upcoming => 'Scheduled',
  DayStatus.none => '',
};

class _HabitFilter extends StatelessWidget {
  const _HabitFilter({
    required this.schedulers,
    required this.selectedId,
    required this.onSelected,
  });

  final List<HabitScheduler> schedulers;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All habits'),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final s in schedulers) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(
                habitIconFor(s.habit.icon),
                color: habitColorFor(s.habit.color),
              ),
              label: Text(s.habit.name),
              selected: selectedId == s.habit.id,
              onSelected: (_) => onSelected(s.habit.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final LocalDay month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              DateFormat.yMMMM().format(month.startOfDay),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.schedulers,
    required this.history,
    required this.single,
    required this.onDayTap,
  });

  final LocalDay month;
  final LocalDay today;
  final List<HabitScheduler> schedulers;
  final Map<String, Map<String, CompletionStatus>> history;
  final HabitScheduler? single;
  final ValueChanged<LocalDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = daysInMonth(month);
    final leading = days.first.weekday - 1; // Monday-first
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final name in weekdayShortNames)
                Expanded(
                  child: Center(
                    child: Text(
                      name.substring(0, 1),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (final day in days)
                single != null
                    ? _HabitDayCell(
                        day: day,
                        isToday: day == today,
                        status: dayStatusFor(
                          scheduler: single!,
                          statusByDay: history[single!.habit.id] ?? const {},
                          day: day,
                          today: today,
                        ),
                        color: habitColorFor(single!.habit.color),
                        onTap: () => onDayTap(day),
                      )
                    : _AllHabitsDayCell(
                        day: day,
                        isToday: day == today,
                        consistency: dayConsistency(
                          schedulers: schedulers,
                          history: history,
                          day: day,
                          today: today,
                        ),
                        onTap: () => onDayTap(day),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitDayCell extends StatelessWidget {
  const _HabitDayCell({
    required this.day,
    required this.isToday,
    required this.status,
    required this.color,
    required this.onTap,
  });

  final LocalDay day;
  final bool isToday;
  final DayStatus status;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color? fill, Color text, IconData? badge) = switch (status) {
      DayStatus.done => (color, Colors.white, null),
      DayStatus.rest => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.self_improvement,
      ),
      DayStatus.paused => (null, scheme.outline, Icons.pause),
      DayStatus.missed => (null, scheme.onSurfaceVariant, null),
      DayStatus.upcoming => (null, scheme.onSurface, null),
      DayStatus.none => (null, scheme.outline.withValues(alpha: 0.6), null),
    };
    return _DayCell(
      day: day,
      isToday: isToday,
      fill: fill,
      textColor: text,
      outlined: status == DayStatus.missed,
      badge: badge,
      semanticsLabel:
          '${DateFormat.MMMMd().format(day.startOfDay)}: ${_statusLabel(status).isEmpty ? 'not scheduled' : _statusLabel(status)}',
      onTap: onTap,
    );
  }
}

class _AllHabitsDayCell extends StatelessWidget {
  const _AllHabitsDayCell({
    required this.day,
    required this.isToday,
    required this.consistency,
    required this.onTap,
  });

  final LocalDay day;
  final bool isToday;
  final Consistency consistency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = consistency.fraction;
    final fill = fraction == null || fraction == 0
        ? null
        : scheme.primary.withValues(alpha: 0.25 + 0.75 * fraction);
    final text = fraction != null && fraction > 0.5
        ? scheme.onPrimary
        : scheme.onSurface;
    final label = consistency.scheduled == 0
        ? 'nothing due'
        : '${consistency.completed} of ${consistency.scheduled} done';
    return _DayCell(
      day: day,
      isToday: isToday,
      fill: fill,
      textColor: text,
      outlined: consistency.scheduled > 0 && consistency.completed == 0,
      semanticsLabel: '${DateFormat.MMMMd().format(day.startOfDay)}: $label',
      onTap: onTap,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.fill,
    required this.textColor,
    required this.outlined,
    required this.semanticsLabel,
    required this.onTap,
    this.badge,
  });

  final LocalDay day;
  final bool isToday;
  final Color? fill;
  final Color textColor;
  final bool outlined;
  final IconData? badge;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: isToday
                  ? Border.all(color: scheme.primary, width: 2)
                  : outlined
                  ? Border.all(color: scheme.outlineVariant)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    bottom: 2,
                    child: Icon(badge, size: 10, color: textColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.month,
    required this.today,
    required this.schedulers,
    required this.history,
  });

  final LocalDay month;
  final LocalDay today;
  final List<HabitScheduler> schedulers;
  final Map<String, Map<String, CompletionStatus>> history;

  @override
  Widget build(BuildContext context) {
    final total = daysInMonth(month)
        .where((d) => !d.isAfter(today))
        .fold<Consistency>(
          Consistency.empty,
          (sum, d) =>
              sum +
              dayConsistency(
                schedulers: schedulers,
                history: history,
                day: d,
                today: today,
              ),
        );
    final text = total.scheduled == 0
        ? 'Nothing was due this month yet.'
        : 'This month: ${total.completed} of ${total.scheduled} · '
              '${total.percentLabel}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        key: const Key('month-summary'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.single});

  final bool single;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(Widget dot, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    Widget dot({Color? fill, Color? border, IconData? icon}) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border == null ? null : Border.all(color: border),
      ),
      child: icon == null ? null : Icon(icon, size: 9),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: single
            ? [
                item(dot(fill: scheme.primary), 'Done'),
                item(
                  dot(
                    fill: scheme.secondaryContainer,
                    icon: Icons.self_improvement,
                  ),
                  'Rest day',
                ),
                item(dot(border: scheme.outlineVariant), 'Not done'),
                item(dot(icon: Icons.pause), 'Paused'),
              ]
            : [
                item(dot(fill: scheme.primary), 'All done'),
                item(
                  dot(fill: scheme.primary.withValues(alpha: 0.45)),
                  'Some done',
                ),
                item(dot(border: scheme.outlineVariant), 'None done'),
              ],
      ),
    );
  }
}
