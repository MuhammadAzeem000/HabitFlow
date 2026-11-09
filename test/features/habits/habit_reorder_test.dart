import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  DateTime clock() => DateTime(2026, 11, 9, 9);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<Map<String, String>> seed(WidgetTester tester) async {
    final ids = <String, String>{};
    for (final name in ['Alpha', 'Bravo', 'Charlie']) {
      ids[name] = (await tester.runAsync(
        () => HabitRepository(db).createHabit(
          HabitDraft(
            name: name,
            frequency: HabitFrequency.daily,
            startDate: const LocalDay(2026, 11, 1),
          ),
        ),
      ))!;
    }
    return ids;
  }

  Future<List<String>> storedOrder(WidgetTester tester) async {
    final habits = (await tester.runAsync(
      () => HabitRepository(db).getActiveHabits(),
    ))!;
    return habits.map((h) => h.name).toList();
  }

  List<String> visibleOrder(WidgetTester tester, List<String> names) {
    final positions = {
      for (final n in names) n: tester.getTopLeft(find.text(n).first).dy,
    };
    return names.toList()
      ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
  }

  Future<void> dragDown(WidgetTester tester, String name, double dy) async {
    final handle = find.byKey(Key('drag-$name'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, dy / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
  }

  testWidgets('dragging a habit persists the new order', (tester) async {
    await seed(tester);
    await pumpApp(tester, db, clock: clock);
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();

    // Move Alpha below Charlie (each tile is ~72 dp tall).
    await dragDown(tester, 'Alpha', 180);

    expect(await storedOrder(tester), ['Bravo', 'Charlie', 'Alpha']);
    expect(visibleOrder(tester, ['Alpha', 'Bravo', 'Charlie']), [
      'Bravo',
      'Charlie',
      'Alpha',
    ]);
  });

  testWidgets('Today follows the new order and history is kept', (
    tester,
  ) async {
    final ids = await seed(tester);
    await tester.runAsync(
      () =>
          CompletionRepository(db)
              .mark(ids['Alpha']!, const LocalDay(2026, 11, 8)),
    );
    await pumpApp(tester, db, clock: clock);
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();

    await dragDown(tester, 'Alpha', 180);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(visibleOrder(tester, ['Alpha', 'Bravo', 'Charlie']), [
      'Bravo',
      'Charlie',
      'Alpha',
    ]);
    final history = (await tester.runAsync(
      () => CompletionRepository(db).getForHabit(ids['Alpha']!),
    ))!;
    expect(history, hasLength(1));
  });

  testWidgets('order survives an app restart', (tester) async {
    await seed(tester);
    await pumpApp(tester, db, clock: clock);
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
    await dragDown(tester, 'Charlie', -180);

    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, db, clock: clock);
    expect(visibleOrder(tester, ['Alpha', 'Bravo', 'Charlie']), [
      'Charlie',
      'Alpha',
      'Bravo',
    ]);
  });
}
