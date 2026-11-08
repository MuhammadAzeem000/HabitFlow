import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/database/database_providers.dart';
import 'package:habitflow/core/utilities/current_day.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/dashboard/application/today_providers.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/application/completion_controller.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/test_container.dart';
import '../../helpers/test_database.dart';

class _FailingCompletionRepository extends CompletionRepository {
  _FailingCompletionRepository(super.db);

  @override
  Future<void> mark(
    String habitId,
    LocalDay day, {
    CompletionStatus status = CompletionStatus.done,
    String? notes,
  }) async => throw Exception('disk full');
}

void main() {
  const today = LocalDay(2026, 11, 9);
  DateTime clock() => DateTime(2026, 11, 9, 9);

  late AppDatabase db;
  late ProviderContainer container;
  late String habitId;

  CompletionController controller() =>
      container.read(completionControllerProvider.notifier);

  Future<List<HabitCompletion>> stored() =>
      CompletionRepository(db).getForHabit(habitId);

  Future<CompletionStatus?> entryStatus() async {
    final entries = await readAsyncData(container, todayEntriesProvider);
    return entries.single.status;
  }

  setUp(() async {
    db = createTestDatabase();
    habitId = await HabitRepository(db).createHabit(
      const HabitDraft(
        name: 'Read',
        frequency: HabitFrequency.daily,
        startDate: LocalDay(2026, 11, 1),
      ),
    );
    container = createTestContainer(db, clock: clock);
    container.listen(todayEntriesProvider, (_, _) {});
    await readAsyncData(container, todayEntriesProvider);
  });
  tearDown(() => db.close());

  test('a tap updates state synchronously, before the write lands', () async {
    final write = controller().toggle(habitId, current: null);

    // Same synchronous turn: no await yet.
    expect(
      container.read(completionControllerProvider)[habitId]?.status,
      CompletionStatus.done,
    );
    expect(await entryStatus(), CompletionStatus.done);

    await write;
    expect((await stored()).single.status, CompletionStatus.done);
  });

  test('optimistic entry is dropped once the database agrees', () async {
    await controller().toggle(habitId, current: null);
    await pumpEventQueue();
    expect(container.read(completionControllerProvider), isEmpty);
    expect(await entryStatus(), CompletionStatus.done);
  });

  test('toggling a done habit clears it', () async {
    await controller().toggle(habitId, current: null);
    await controller().toggle(habitId, current: CompletionStatus.done);
    expect(await stored(), isEmpty);
  });

  test('rapid taps are applied in order; the last one wins', () async {
    final writes = [
      controller().setStatus(habitId, CompletionStatus.done),
      controller().setStatus(habitId, null),
      controller().setStatus(habitId, CompletionStatus.done),
    ];
    expect(
      container.read(completionControllerProvider)[habitId]?.status,
      CompletionStatus.done,
    );
    await Future.wait(writes);
    expect((await stored()).single.status, CompletionStatus.done);
  });

  test('undo restores the previous state', () async {
    await controller().toggle(habitId, current: null);
    await controller().setStatus(habitId, null); // Undo
    await pumpEventQueue();
    expect(await stored(), isEmpty);
    expect(await entryStatus(), isNull);
  });

  test('a failed write rolls back to the stored state and reports', () async {
    final failing = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        completionRepositoryProvider.overrideWithValue(
          _FailingCompletionRepository(db),
        ),
      ],
    );
    addTearDown(failing.dispose);
    failing.listen(todayEntriesProvider, (_, _) {});
    await readAsyncData(failing, todayEntriesProvider);

    final c = failing.read(completionControllerProvider.notifier);
    await expectLater(c.toggle(habitId, current: null), throwsException);

    expect(failing.read(completionControllerProvider), isEmpty);
    final entries = await readAsyncData(failing, todayEntriesProvider);
    expect(entries.single.status, isNull);
    expect(await stored(), isEmpty);
  });

  test('writes go to the day the tap happened', () async {
    await controller().toggle(habitId, current: null);
    expect((await stored()).single.completionDate, today.key);
  });
}
