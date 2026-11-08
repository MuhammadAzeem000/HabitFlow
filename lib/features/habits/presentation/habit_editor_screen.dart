import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../../core/utilities/local_day.dart';
import '../domain/habit_appearance.dart';
import '../domain/habit_draft.dart';
import '../domain/habit_schedule.dart';
import 'habit_actions.dart';
import 'widgets/habit_avatar.dart';

/// Create a habit (no [habitId]) or edit an existing one.
class HabitEditorScreen extends ConsumerStatefulWidget {
  const HabitEditorScreen({this.habitId, super.key});

  final String? habitId;

  @override
  ConsumerState<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends ConsumerState<HabitEditorScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  Habit? _existing;
  bool _loading = false;
  bool _saving = false;
  String? _nameError;
  String? _scheduleError;

  String _icon = defaultHabitIcon;
  String _color = defaultHabitColor;
  HabitFrequency _frequency = HabitFrequency.daily;
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  int _weeklyTarget = 3;
  late LocalDay _startDate;

  bool get _isEditing => widget.habitId != null;

  @override
  void initState() {
    super.initState();
    _startDate = ref.read(currentDayProvider);
    if (_isEditing) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final habit = await ref
        .read(habitRepositoryProvider)
        .getHabit(widget.habitId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _existing = habit;
      if (habit == null) return;
      _name.text = habit.name;
      _description.text = habit.description ?? '';
      _icon = habit.icon ?? defaultHabitIcon;
      _color = habit.color ?? defaultHabitColor;
      _frequency = habit.frequency;
      final days = decodeWeekdays(habit.targetDays);
      if (days.isNotEmpty) _weekdays = days.toSet();
      _weeklyTarget = habit.weeklyTarget ?? 3;
      _startDate = LocalDay.parse(habit.startDate);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  HabitDraft get _draft => HabitDraft(
    name: _name.text,
    description: _description.text,
    icon: _icon,
    color: _color,
    frequency: _frequency,
    targetDays: _weekdays.toList(),
    weeklyTarget: _weeklyTarget,
    startDate: _startDate,
    reminderTime: _existing?.reminderTime,
  );

  Future<void> _save() async {
    final draft = _draft;
    final error = draft.validate();
    if (error != null) {
      final nameInvalid =
          draft.name.trim().isEmpty || draft.name.trim().length > 100;
      setState(() {
        _nameError = nameInvalid ? error : null;
        _scheduleError = nameInvalid ? null : error;
      });
      return;
    }
    setState(() {
      _nameError = null;
      _scheduleError = null;
      _saving = true;
    });
    final repo = ref.read(habitRepositoryProvider);
    if (_isEditing) {
      await repo.updateHabit(widget.habitId!, draft);
    } else {
      await repo.createHabit(draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.startOfDay,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _startDate = LocalDay.fromDateTime(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_isEditing && _existing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This habit no longer exists.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit habit' : 'New habit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: HabitAvatar(icon: _icon, color: _color, size: 52),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('habit-name'),
                  controller: _name,
                  autofocus: !_isEditing,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Habit name',
                    hintText: 'e.g. Drink water',
                    errorText: _nameError,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
              ),
            ],
          ),
          TextField(
            controller: _description,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const _Section('Icon'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in habitIcons.entries)
                _ChoiceCircle(
                  selected: entry.key == _icon,
                  color: habitColorFor(_color),
                  tooltip: entry.key,
                  onTap: () => setState(() => _icon = entry.key),
                  child: Icon(entry.value),
                ),
            ],
          ),
          const _Section('Colour'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in habitColors)
                _ChoiceCircle(
                  selected: hex == _color,
                  color: habitColorFor(hex),
                  filled: true,
                  tooltip: 'Colour',
                  onTap: () => setState(() => _color = hex),
                  child: hex == _color
                      ? const Icon(Icons.check, color: Colors.white)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
          const _Section('Schedule'),
          SegmentedButton<HabitFrequency>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: HabitFrequency.daily, label: Text('Daily')),
              ButtonSegment(
                value: HabitFrequency.weekdays,
                label: Text('Some days'),
              ),
              ButtonSegment(
                value: HabitFrequency.weeklyTarget,
                label: Text('Weekly goal'),
              ),
            ],
            selected: {_frequency},
            onSelectionChanged: (s) => setState(() {
              _frequency = s.first;
              _scheduleError = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_frequency == HabitFrequency.weekdays)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayShortNames[d - 1]),
                    selected: _weekdays.contains(d),
                    onSelected: (on) => setState(() {
                      _scheduleError = null;
                      on ? _weekdays.add(d) : _weekdays.remove(d);
                    }),
                  ),
              ],
            ),
          if (_frequency == HabitFrequency.weeklyTarget)
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Fewer',
                  onPressed: _weeklyTarget > 1
                      ? () => setState(() => _weeklyTarget--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '$_weeklyTarget× per week',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'More',
                  onPressed: _weeklyTarget < 7
                      ? () => setState(() => _weeklyTarget++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          if (_scheduleError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _scheduleError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Start date'),
            subtitle: Text(DateFormat.yMMMEd().format(_startDate.startOfDay)),
            onTap: _pickStartDate,
          ),
          if (_isEditing) ...[
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive habit'),
              subtitle: const Text('Hide it and keep its history'),
              onTap: () async {
                final navigator = Navigator.of(context);
                await archiveHabit(context, ref, _existing!);
                navigator.pop();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete habit',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('Permanently remove it and its history'),
              onTap: () async {
                final navigator = Navigator.of(context);
                if (await confirmAndDeleteHabit(context, ref, _existing!)) {
                  navigator.pop();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ChoiceCircle extends StatelessWidget {
  const _ChoiceCircle({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
    required this.tooltip,
    this.filled = false,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled
                  ? color
                  : selected
                  ? color.withValues(alpha: 0.18)
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                color: selected ? scheme.onSurface : Colors.transparent,
                width: 2,
              ),
            ),
            child: IconTheme(
              data: IconThemeData(
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
