import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late HabitRepository habits;
  late CompletionRepository completions;
  var now = DateTime(2026, 11, 8, 9);

  HabitDraft draft(
    String name, {
    HabitFrequency frequency = HabitFrequency.daily,
    List<int> days = const [],
    int? weeklyTarget,
    LocalDay? start,
  }) => HabitDraft(
    name: name,
    frequency: frequency,
    targetDays: days,
    weeklyTarget: weeklyTarget,
    startDate: start ?? const LocalDay(2026, 11, 1),
  );

  setUp(() {
    now = DateTime(2026, 11, 8, 9);
    db = createTestDatabase();
    habits = HabitRepository(db, clock: () => now);
    completions = CompletionRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('create persists fields and appends to the end of the order', () async {
    final a = await habits.createHabit(draft('  Read  '));
    final b = await habits.createHabit(
      draft('Gym', frequency: HabitFrequency.weekdays, days: [5, 1, 3, 1]),
    );

    final list = await habits.getActiveHabits();
    expect(list.map((h) => h.id), [a, b]);
    expect(list[0].name, 'Read');
    expect(list[0].orderIndex, 0);
    expect(list[1].orderIndex, 1);
    expect(list[1].targetDays, '1,3,5');
    expect(list[1].startDate, '2026-11-01');
  });

  test(
    'create records the initial schedule version at the start date',
    () async {
      final id = await habits.createHabit(draft('Read'));
      final history = await habits.getScheduleHistory(id);
      expect(history, hasLength(1));
      expect(history.single.effectiveFrom, '2026-11-01');
      expect(history.single.frequency, HabitFrequency.daily);
    },
  );

  test('invalid drafts are rejected', () async {
    expect(() => habits.createHabit(draft('   ')), throwsArgumentError);
    expect(
      () =>
          habits.createHabit(draft('Gym', frequency: HabitFrequency.weekdays)),
      throwsArgumentError,
    );
    expect(
      () => habits.createHabit(
        draft('Run', frequency: HabitFrequency.weeklyTarget, weeklyTarget: 9),
      ),
      throwsArgumentError,
    );
  });

  test('schedule edit adds a version from today and keeps the past', () async {
    final id = await habits.createHabit(draft('Read'));
    await habits.updateHabit(
      id,
      draft('Read', frequency: HabitFrequency.weekdays, days: [1, 3]),
    );

    final history = await habits.getScheduleHistory(id);
    expect(history.map((s) => s.effectiveFrom), ['2026-11-01', '2026-11-08']);
    expect(history.first.frequency, HabitFrequency.daily);
    expect(history.last.frequency, HabitFrequency.weekdays);
    expect(history.last.targetDays, '1,3');
  });

  test(
    'multiple schedule edits on one day collapse into one version',
    () async {
      final id = await habits.createHabit(draft('Read'));
      await habits.updateHabit(
        id,
        draft('Read', frequency: HabitFrequency.weekdays, days: [1]),
      );
      await habits.updateHabit(
        id,
        draft('Read', frequency: HabitFrequency.weeklyTarget, weeklyTarget: 3),
      );

      final history = await habits.getScheduleHistory(id);
      expect(history, hasLength(2));
      expect(history.last.frequency, HabitFrequency.weeklyTarget);
      expect(history.last.weeklyTarget, 3);
      expect(history.last.targetDays, isNull);
    },
  );

  test('non-schedule edits do not add a schedule version', () async {
    final id = await habits.createHabit(draft('Read'));
    await habits.updateHabit(id, draft('Read more'));
    expect(await habits.getScheduleHistory(id), hasLength(1));
    expect((await habits.getHabit(id))!.name, 'Read more');
  });

  test('archive hides the habit but preserves its history', () async {
    final id = await habits.createHabit(draft('Read'));
    await completions.mark(id, const LocalDay(2026, 11, 7));

    await habits.setArchived(id, archived: true);
    expect(await habits.getActiveHabits(), isEmpty);
    expect(await completions.getForHabit(id), hasLength(1));

    await habits.setArchived(id, archived: false);
    expect(await habits.getActiveHabits(), hasLength(1));
  });

  test('reorder persists order_index without touching history', () async {
    final a = await habits.createHabit(draft('A'));
    final b = await habits.createHabit(draft('B'));
    final c = await habits.createHabit(draft('C'));
    await completions.mark(a, const LocalDay(2026, 11, 7));

    await habits.reorder([c, a, b]);

    expect((await habits.getActiveHabits()).map((h) => h.id), [c, a, b]);
    expect(await completions.getForHabit(a), hasLength(1));
  });

  test('delete removes the habit, its completions and schedules', () async {
    final id = await habits.createHabit(draft('Read'));
    await completions.mark(id, const LocalDay(2026, 11, 7));

    await habits.deleteHabit(id);

    expect(await habits.getHabit(id), isNull);
    expect(await completions.getForHabit(id), isEmpty);
    expect(await habits.getScheduleHistory(id), isEmpty);
  });

  test('pause stores a start and end date', () async {
    final id = await habits.createHabit(draft('Read'));
    await habits.pause(
      id,
      from: const LocalDay(2026, 11, 8),
      until: const LocalDay(2026, 11, 20),
    );
    final h = (await habits.getHabit(id))!;
    expect(h.pausedFrom, '2026-11-08');
    expect(h.pausedUntil, '2026-11-20');
  });

  test(
    'resume keeps days already paused, ending the pause yesterday',
    () async {
      final id = await habits.createHabit(draft('Read'));
      await habits.pause(
        id,
        from: const LocalDay(2026, 11, 5),
        until: const LocalDay(2026, 11, 20),
      );
      await habits.resume(id, today: const LocalDay(2026, 11, 8));
      final h = (await habits.getHabit(id))!;
      expect(h.pausedFrom, '2026-11-05');
      expect(h.pausedUntil, '2026-11-07');
    },
  );

  test('resuming on the day a pause starts removes it', () async {
    final id = await habits.createHabit(draft('Read'));
    await habits.pause(
      id,
      from: const LocalDay(2026, 11, 8),
      until: const LocalDay(2026, 11, 20),
    );
    await habits.resume(id, today: const LocalDay(2026, 11, 8));
    final h = (await habits.getHabit(id))!;
    expect(h.pausedFrom, isNull);
    expect(h.pausedUntil, isNull);
  });

  test('restorePause puts back an exact state (undo)', () async {
    final id = await habits.createHabit(draft('Read'));
    await habits.pause(
      id,
      from: const LocalDay(2026, 11, 8),
      until: const LocalDay(2026, 11, 20),
    );
    await habits.restorePause(id);
    expect((await habits.getHabit(id))!.pausedUntil, isNull);
  });

  test('active habits stream emits updates', () async {
    final stream = habits.watchActiveHabits();
    final expectation = expectLater(
      stream.map((l) => l.map((h) => h.name).toList()),
      emitsInOrder([
        <String>[],
        ['Read'],
      ]),
    );
    await pumpEventQueue();
    await habits.createHabit(draft('Read'));
    await expectation;
  });
}
