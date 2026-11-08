import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// Device-testing regression: an "Undo" snackbar must not follow the user
/// onto the next page, where its button could be tapped by accident.
void main() {
  late AppDatabase db;
  DateTime clock() => DateTime(2026, 11, 9, 9);

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('opening a page dismisses the Undo snackbar', (tester) async {
    await tester.runAsync(
      () => HabitRepository(db).createHabit(
        const HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      ),
    );
    await pumpApp(tester, db, clock: clock);

    await tester.longPress(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a rest day'));
    await settle(tester);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Try a free 30-day challenge'));
    await settle(tester);

    expect(find.text('30-day challenge'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });
}
