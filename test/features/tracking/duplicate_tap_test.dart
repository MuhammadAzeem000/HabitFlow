import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/dashboard/application/today_providers.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/application/completion_controller.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_container.dart';
import '../../helpers/test_database.dart';

void main() {
  DateTime clock() => DateTime(2026, 11, 9, 9);
  const day = LocalDay(2026, 11, 9);
  const habitDraft = HabitDraft(
    name: 'Read',
    frequency: HabitFrequency.daily,
    startDate: LocalDay(2026, 11, 1),
  );

  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('CompletionController tap guard', () {
    late ProviderContainer container;
    late String habitId;
    var elapsed = Duration.zero;

    setUp(() async {
      elapsed = Duration.zero;
      habitId = await HabitRepository(db).createHabit(habitDraft);
      container = createTestContainer(
        db,
        clock: clock,
        monotonicClock: () => elapsed,
      );
      container.listen(todayEntriesProvider, (_, _) {});
      await readAsyncData(container, todayEntriesProvider);
    });

    CompletionController controller() =>
        container.read(completionControllerProvider.notifier);

    test('a second tap inside the window is ignored', () async {
      final first = controller().toggle(habitId, current: null);
      elapsed += const Duration(milliseconds: 150);
      final second = controller().toggle(
        habitId,
        current: CompletionStatus.done,
      );

      expect(first, isNotNull);
      expect(second, isNull);
      await first;
      final rows = await CompletionRepository(db).getForHabit(habitId);
      expect(rows.single.status, CompletionStatus.done);
    });

    test('a tap after the window is accepted', () async {
      await controller().toggle(habitId, current: null);
      elapsed += CompletionController.duplicateTapWindow;
      final second = controller().toggle(
        habitId,
        current: CompletionStatus.done,
      );

      expect(second, isNotNull);
      await second;
      expect(await CompletionRepository(db).getForHabit(habitId), isEmpty);
    });

    test('the guard is per habit', () async {
      final other = await HabitRepository(db).createHabit(
        const HabitDraft(
          name: 'Walk',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      );
      final a = controller().toggle(habitId, current: null);
      final b = controller().toggle(other, current: null);
      expect(a, isNotNull);
      expect(b, isNotNull);
      await Future.wait([a!, b!]);
    });

    test('undo is never blocked by the guard', () async {
      await controller().toggle(habitId, current: null);
      await controller().setStatus(habitId, null); // immediate Undo
      expect(await CompletionRepository(db).getForHabit(habitId), isEmpty);
    });
  });

  group('database guard', () {
    test('concurrent marks for the same day store exactly one row', () async {
      final id = await HabitRepository(db).createHabit(habitDraft);
      final repo = CompletionRepository(db);
      await Future.wait(List.generate(10, (_) => repo.mark(id, day)));
      expect(await repo.getForHabit(id), hasLength(1));
    });
  });

  testWidgets('a fast double tap on the Today card counts once', (
    tester,
  ) async {
    final id = (await tester.runAsync(
      () => HabitRepository(db).createHabit(habitDraft),
    ))!;
    // Time stands still: the second tap lands inside the guard window.
    await pumpApp(
      tester,
      db,
      clock: clock,
      monotonicClock: () => Duration.zero,
    );

    final button = find.byKey(const Key('complete-Read'));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(button);
    await settle(tester);

    expect(find.text('1 of 1 done'), findsOneWidget);
    final rows = (await tester.runAsync(
      () => CompletionRepository(db).getForHabit(id),
    ))!;
    expect(rows.single.status, CompletionStatus.done);
  });
}
