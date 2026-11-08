import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utilities/current_day.dart';
import '../../dashboard/application/today_providers.dart';

/// An optimistic state for one habit today, shown until the database
/// confirms it. A null [status] means "not done".
@immutable
class PendingCompletion {
  const PendingCompletion(this.status);

  final CompletionStatus? status;
}

/// Optimistic completion state for today, keyed by habit id.
final completionControllerProvider =
    NotifierProvider<CompletionController, Map<String, PendingCompletion>>(
      CompletionController.new,
    );

/// Instant habit completion (HF-006).
///
/// A tap updates [state] synchronously so the UI changes on the same frame,
/// then the write goes to the local database. Writes for the same habit are
/// queued, so the stored result always matches the last tap. An optimistic
/// entry is dropped once the database stream reports the same value; if a
/// write fails, it is dropped immediately and the UI falls back to the
/// stored value.
class CompletionController extends Notifier<Map<String, PendingCompletion>> {
  /// A second tap on the same habit within this window is treated as an
  /// accidental double tap and ignored (HF-007).
  static const duplicateTapWindow = Duration(milliseconds: 400);

  final _queues = <String, Future<void>>{};
  final _inFlight = <String, int>{};
  final _lastTap = <String, Duration>{};

  @override
  Map<String, PendingCompletion> build() {
    // A new day starts with no pending state.
    ref.watch(currentDayProvider);
    ref.listen(todayCompletionsProvider, (_, next) {
      if (next case AsyncData(:final value)) _reconcile(value);
    });
    return const {};
  }

  /// Marks [habitId] done, or not done if [current] is done.
  ///
  /// Returns null (and does nothing) when the tap repeats the previous one
  /// within [duplicateTapWindow]; otherwise returns the pending write.
  Future<void>? toggle(String habitId, {required CompletionStatus? current}) {
    final now = ref.read(monotonicClockProvider)();
    final last = _lastTap[habitId];
    if (last != null && now - last < duplicateTapWindow) return null;
    _lastTap[habitId] = now;

    return setStatus(
      habitId,
      current == CompletionStatus.done ? null : CompletionStatus.done,
    );
  }

  /// Sets today's state for [habitId] (null clears it). Completes when the
  /// write is stored; throws if the write fails.
  Future<void> setStatus(String habitId, CompletionStatus? status) {
    final day = ref.read(currentDayProvider);
    final repo = ref.read(completionRepositoryProvider);

    state = {...state, habitId: PendingCompletion(status)};
    _inFlight[habitId] = (_inFlight[habitId] ?? 0) + 1;

    final previous = _queues[habitId] ?? Future<void>.value();
    final write = previous
        .catchError((Object _) {})
        .then(
          (_) => status == null
              ? repo.clear(habitId, day)
              : repo.mark(habitId, day, status: status),
        );
    _queues[habitId] = write;

    return write.then(
      (_) => _finish(habitId, failed: false),
      onError: (Object error, StackTrace stack) {
        _finish(habitId, failed: true);
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  void _finish(String habitId, {required bool failed}) {
    final remaining = (_inFlight[habitId] ?? 1) - 1;
    if (remaining <= 0) {
      _inFlight.remove(habitId);
      _queues.remove(habitId);
    } else {
      _inFlight[habitId] = remaining;
    }
    if (!ref.mounted) return;

    if (failed && remaining <= 0) {
      state = {...state}..remove(habitId);
      return;
    }
    final stored = ref.read(todayCompletionsProvider).value;
    if (stored != null) _reconcile(stored);
  }

  /// Drops optimistic entries that the database now agrees with.
  void _reconcile(List<HabitCompletion> stored) {
    if (state.isEmpty) return;
    final byHabit = {for (final c in stored) c.habitId: c.status};
    final next = {...state}
      ..removeWhere(
        (id, pending) =>
            (_inFlight[id] ?? 0) == 0 && byHabit[id] == pending.status,
      );
    if (next.length != state.length) state = next;
  }
}
