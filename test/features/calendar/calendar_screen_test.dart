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
  DateTime clock() => DateTime(2026, 11, 12, 9); // Thursday
  LocalDay nov(int d) => LocalDay(2026, 11, d);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  /// Read (daily from Nov 9): done 9, rest 10, missed 11.
  /// Walk (daily from Nov 9): done 9 and 11.
  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      final habits = HabitRepository(db);
      final completions = CompletionRepository(db);
      final read = await habits.createHabit(
        HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.daily,
          startDate: nov(9),
        ),
      );
      final walk = await habits.createHabit(
        HabitDraft(
          name: 'Walk',
          frequency: HabitFrequency.daily,
          startDate: nov(9),
        ),
      );
      await completions.mark(read, nov(9));
      await completions.mark(read, nov(10), status: CompletionStatus.skipped);
      await completions.mark(walk, nov(9));
      await completions.mark(walk, nov(11));
    });
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await pumpApp(tester, db, clock: clock);
    await tester.tap(find.text('Calendar'));
    await settle(tester);
  }

  String summary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('month-summary'))).data!;

  testWidgets('all-habits view shows each day\'s share and a summary', (
    tester,
  ) async {
    await seed(tester);
    await openCalendar(tester);

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('November 9: 2 of 2 done'), findsOneWidget);
    // Read's rest day is excluded: only Walk was due on the 10th.
    expect(find.bySemanticsLabel('November 10: 0 of 1 done'), findsOneWidget);
    expect(find.bySemanticsLabel('November 11: 1 of 2 done'), findsOneWidget);
    expect(find.bySemanticsLabel('November 8: nothing due'), findsOneWidget);
    // 9th: 2/2, 10th: 0/1, 11th: 1/2, 12th (today) open → 3 of 5.
    expect(summary(tester), 'This month: 3 of 5 · 60%');
  });

  testWidgets('filtering to one habit shows its day states', (tester) async {
    await seed(tester);
    await openCalendar(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Read'));
    await settle(tester);

    expect(find.bySemanticsLabel('November 9: Done'), findsOneWidget);
    expect(find.bySemanticsLabel('November 10: Rest day'), findsOneWidget);
    expect(find.bySemanticsLabel('November 11: Not done'), findsOneWidget);
    expect(find.bySemanticsLabel('November 12: Scheduled'), findsOneWidget);
    expect(find.bySemanticsLabel('November 8: not scheduled'), findsOneWidget);
    expect(summary(tester), 'This month: 1 of 2 · 50%');
  });

  testWidgets('tapping a day lists what happened', (tester) async {
    await seed(tester);
    await openCalendar(tester);

    await tester.tap(find.bySemanticsLabel('November 10: 0 of 1 done'));
    await tester.pumpAndSettle();

    expect(find.text('Tuesday, November 10, 2026'), findsOneWidget);
    expect(find.text('Rest day'), findsOneWidget);
    expect(find.text('Not done'), findsOneWidget);
  });

  testWidgets('month navigation', (tester) async {
    await seed(tester);
    await openCalendar(tester);

    await tester.tap(find.byTooltip('Previous month'));
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(summary(tester), 'Nothing was due this month yet.');

    await tester.tap(find.byTooltip('Next month'));
    await tester.tap(find.byTooltip('Next month'));
    await settle(tester);
    expect(find.text('December 2026'), findsOneWidget);
  });
}
