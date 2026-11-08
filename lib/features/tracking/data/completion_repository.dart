import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/local_day.dart';

/// Local persistence for per-day habit states (done / rest day).
///
/// The `(habit_id, completion_date)` unique key guarantees at most one record
/// per habit per day; [mark] is an idempotent upsert, so repeated taps can
/// never create duplicates.
class CompletionRepository {
  CompletionRepository(this._db, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  $HabitCompletionsTable get _table => _db.habitCompletions;

  Stream<List<HabitCompletion>> watchForDay(LocalDay day) {
    return (_db.select(
      _table,
    )..where((c) => c.completionDate.equals(day.key))).watch();
  }

  /// Records between [from] and [to], inclusive.
  Stream<List<HabitCompletion>> watchForRange(LocalDay from, LocalDay to) {
    return (_db.select(_table)
          ..where((c) => c.completionDate.isBetweenValues(from.key, to.key)))
        .watch();
  }

  /// Every stored record (for statistics).
  Stream<List<HabitCompletion>> watchAll() => _db.select(_table).watch();

  Future<List<HabitCompletion>> getForHabit(String habitId) {
    return (_db.select(_table)
          ..where((c) => c.habitId.equals(habitId))
          ..orderBy([(c) => OrderingTerm.asc(c.completionDate)]))
        .get();
  }

  /// Sets the state of [habitId] on [day], replacing any existing state.
  Future<void> mark(
    String habitId,
    LocalDay day, {
    CompletionStatus status = CompletionStatus.done,
    String? notes,
  }) async {
    final now = _clock();
    await _db
        .into(_table)
        .insert(
          HabitCompletionsCompanion.insert(
            id: _uuid.v4(),
            habitId: habitId,
            completionDate: day.key,
            status: Value(status),
            completedAt: now,
            notes: Value(notes),
          ),
          onConflict: DoUpdate(
            (old) => HabitCompletionsCompanion(
              status: Value(status),
              completedAt: Value(now),
              notes: Value(notes),
            ),
            target: [_table.habitId, _table.completionDate],
          ),
        );
  }

  /// Removes any state for [habitId] on [day] (used for undo).
  Future<void> clear(String habitId, LocalDay day) async {
    await (_db.delete(_table)..where(
          (c) => c.habitId.equals(habitId) & c.completionDate.equals(day.key),
        ))
        .go();
  }
}
