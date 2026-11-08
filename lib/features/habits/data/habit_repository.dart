import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';
import '../domain/habit_draft.dart';

/// Local persistence for habits and their schedule history.
class HabitRepository {
  HabitRepository(this._db, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  $HabitsTable get _habits => _db.habits;

  SimpleSelectStatement<$HabitsTable, Habit> _ordered({
    required bool archived,
  }) {
    return _db.select(_habits)
      ..where((h) => h.isArchived.equals(archived))
      ..orderBy([
        (h) => OrderingTerm.asc(h.orderIndex),
        (h) => OrderingTerm.asc(h.createdAt),
      ]);
  }

  /// Active habits in user-defined order.
  Stream<List<Habit>> watchActiveHabits() => _ordered(archived: false).watch();

  Stream<List<Habit>> watchArchivedHabits() => _ordered(archived: true).watch();

  Future<List<Habit>> getActiveHabits() => _ordered(archived: false).get();

  Future<Habit?> getHabit(String id) =>
      (_db.select(_habits)..where((h) => h.id.equals(id))).getSingleOrNull();

  /// Creates a habit at the end of the list and returns its id.
  Future<String> createHabit(HabitDraft draft) {
    _checkValid(draft);
    return _db.transaction(() async {
      final now = _clock();
      final id = _uuid.v4();
      final maxOrder = _habits.orderIndex.max();
      final row = await (_db.selectOnly(
        _habits,
      )..addColumns([maxOrder])).getSingle();
      final nextOrder = (row.read(maxOrder) ?? -1) + 1;

      await _db
          .into(_habits)
          .insert(
            HabitsCompanion.insert(
              id: id,
              name: draft.name.trim(),
              description: Value(_blankToNull(draft.description)),
              icon: Value(draft.icon),
              color: Value(draft.color),
              frequency: draft.frequency,
              targetDays: Value(_targetDaysFor(draft)),
              weeklyTarget: Value(_weeklyTargetFor(draft)),
              reminderTime: Value(draft.reminderTime),
              startDate: draft.startDate.key,
              orderIndex: Value(nextOrder),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _recordSchedule(id, draft, effectiveFrom: draft.startDate);
      return id;
    });
  }

  /// Updates a habit. A schedule change is recorded as a new schedule
  /// version effective today, so past days keep their original schedule.
  Future<void> updateHabit(String id, HabitDraft draft) {
    _checkValid(draft);
    return _db.transaction(() async {
      final existing = await getHabit(id);
      if (existing == null) throw StateError('Habit $id not found');

      await (_db.update(_habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(
          name: Value(draft.name.trim()),
          description: Value(_blankToNull(draft.description)),
          icon: Value(draft.icon),
          color: Value(draft.color),
          frequency: Value(draft.frequency),
          targetDays: Value(_targetDaysFor(draft)),
          weeklyTarget: Value(_weeklyTargetFor(draft)),
          reminderTime: Value(draft.reminderTime),
          startDate: Value(draft.startDate.key),
          updatedAt: Value(_clock()),
        ),
      );

      final changed = scheduleChanged(
        oldFrequency: existing.frequency,
        oldTargetDays: existing.targetDays,
        oldWeeklyTarget: existing.weeklyTarget,
        newFrequency: draft.frequency,
        newTargetDays: draft.targetDays,
        newWeeklyTarget: draft.weeklyTarget,
      );
      if (changed) {
        final today = LocalDay.today(_clock);
        // A habit that hasn't started yet has no history to protect.
        final effective = draft.startDate.isAfter(today)
            ? draft.startDate
            : today;
        await _recordSchedule(id, draft, effectiveFrom: effective);
      }
    });
  }

  /// Archiving hides a habit but keeps all of its history.
  Future<void> setArchived(String id, {required bool archived}) async {
    await (_db.update(_habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(isArchived: Value(archived), updatedAt: Value(_clock())),
    );
  }

  /// Pauses from [from] through [until] (inclusive). Paused days are never
  /// misses, and days before [from] keep their history.
  Future<void> pause(
    String id, {
    required LocalDay from,
    required LocalDay until,
  }) => _writePause(id, from: from, until: until);

  /// Ends a pause so the habit is due again from [today]. Days already
  /// paused stay paused; a pause that hadn't started yet is removed.
  Future<void> resume(String id, {required LocalDay today}) async {
    final habit = await getHabit(id);
    if (habit == null || habit.pausedUntil == null) return;
    final from = habit.pausedFrom == null
        ? null
        : LocalDay.parse(habit.pausedFrom!);
    final yesterday = today.addDays(-1);
    if (from != null && from.isAfter(yesterday)) {
      await _writePause(id, from: null, until: null);
    } else {
      await _writePause(id, from: from, until: yesterday);
    }
  }

  /// Restores an exact pause state (used by undo).
  Future<void> restorePause(String id, {String? from, String? until}) =>
      _writePauseKeys(id, from: from, until: until);

  Future<void> _writePause(String id, {LocalDay? from, LocalDay? until}) =>
      _writePauseKeys(id, from: from?.key, until: until?.key);

  Future<void> _writePauseKeys(String id, {String? from, String? until}) async {
    await (_db.update(_habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        pausedFrom: Value(from),
        pausedUntil: Value(until),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// Permanently deletes a habit and (via cascade) all of its history.
  Future<void> deleteHabit(String id) async {
    await (_db.delete(_habits)..where((h) => h.id.equals(id))).go();
  }

  /// Persists a new order. Only `order_index` changes; history is untouched.
  Future<void> reorder(List<String> orderedIds) {
    return _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _habits,
          HabitsCompanion(orderIndex: Value(i)),
          where: (h) => h.id.equals(orderedIds[i]),
        );
      }
    });
  }

  /// Schedule versions for a habit, oldest first.
  Future<List<HabitScheduleEntry>> getScheduleHistory(String habitId) {
    return (_db.select(_db.habitSchedules)
          ..where((s) => s.habitId.equals(habitId))
          ..orderBy([(s) => OrderingTerm.asc(s.effectiveFrom)]))
        .get();
  }

  Stream<List<HabitScheduleEntry>> watchAllScheduleHistory() {
    return (_db.select(
      _db.habitSchedules,
    )..orderBy([(s) => OrderingTerm.asc(s.effectiveFrom)])).watch();
  }

  Future<void> _recordSchedule(
    String habitId,
    HabitDraft draft, {
    required LocalDay effectiveFrom,
  }) async {
    final table = _db.habitSchedules;
    await _db
        .into(table)
        .insert(
          HabitSchedulesCompanion.insert(
            id: _uuid.v4(),
            habitId: habitId,
            effectiveFrom: effectiveFrom.key,
            frequency: draft.frequency,
            targetDays: Value(_targetDaysFor(draft)),
            weeklyTarget: Value(_weeklyTargetFor(draft)),
          ),
          // Several edits on the same day collapse into one version.
          onConflict: DoUpdate(
            (old) => HabitSchedulesCompanion(
              frequency: Value(draft.frequency),
              targetDays: Value(_targetDaysFor(draft)),
              weeklyTarget: Value(_weeklyTargetFor(draft)),
            ),
            target: [table.habitId, table.effectiveFrom],
          ),
        );
  }

  static void _checkValid(HabitDraft draft) {
    final error = draft.validate();
    if (error != null) throw ArgumentError(error);
  }

  static String? _targetDaysFor(HabitDraft d) =>
      d.frequency == HabitFrequency.weekdays
      ? encodeWeekdays(d.targetDays)
      : null;

  static int? _weeklyTargetFor(HabitDraft d) =>
      d.frequency == HabitFrequency.weeklyTarget ? d.weeklyTarget : null;

  static String? _blankToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
