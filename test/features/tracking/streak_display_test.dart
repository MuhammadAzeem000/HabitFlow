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
  const today = LocalDay(2026, 11, 9);
  DateTime clock() => DateTime(2026, 11, 9, 9);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> seedWithHistory(WidgetTester tester, List<int> daysAgo) async {
    await tester.runAsync(() async {
      final id = await HabitRepository(db).createHabit(
        const HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      );
      for (final n in daysAgo) {
        await CompletionRepository(db).mark(id, today.addDays(-n));
      }
    });
  }

  testWidgets('Today card shows the streak and updates on tap', (tester) async {
    await seedWithHistory(tester, [1, 2, 3]);
    await pumpApp(tester, db, clock: clock);

    expect(find.text('Every day · 3-day streak'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-Read')));
    await tester.pump();
    expect(find.text('Every day · 4-day streak'), findsOneWidget);
  });

  testWidgets('short streaks are not shown', (tester) async {
    await seedWithHistory(tester, [1]);
    await pumpApp(tester, db, clock: clock);
    expect(find.text('Every day'), findsOneWidget);
  });

  testWidgets('edit screen shows current and best streak', (tester) async {
    // Best run of 4 (days 9–6 ago), then a miss, then 2 in a row.
    await seedWithHistory(tester, [1, 2, 6, 7, 8]);
    await pumpApp(tester, db, clock: clock);

    await tester.tap(find.text('Read'));
    await settle(tester);

    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
  });
}
