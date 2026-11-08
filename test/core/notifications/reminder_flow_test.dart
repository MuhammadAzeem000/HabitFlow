import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';

import '../../helpers/fake_reminder_service.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeReminderService reminders;
  DateTime clock() => DateTime(2026, 11, 9, 8); // Monday 08:00

  setUp(() {
    db = createTestDatabase();
    reminders = FakeReminderService();
  });
  tearDown(() => db.close());

  Future<String> seed(WidgetTester tester, {String? reminder}) async =>
      (await tester.runAsync(
        () => HabitRepository(db).createHabit(
          HabitDraft(
            name: 'Read',
            frequency: HabitFrequency.daily,
            startDate: const LocalDay(2026, 11, 1),
            reminderTime: reminder,
          ),
        ),
      ))!;

  Future<void> waitForSync(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  testWidgets('habits with a reminder time are scheduled on launch', (
    tester,
  ) async {
    await seed(tester, reminder: '09:30');
    await pumpApp(tester, db, clock: clock, reminders: reminders);
    await waitForSync(tester);

    expect(reminders.latest, hasLength(14));
    expect(reminders.latest.first.when, DateTime(2026, 11, 9, 9, 30));
  });

  testWidgets('completing today drops today\'s reminder', (tester) async {
    await seed(tester, reminder: '09:30');
    await pumpApp(tester, db, clock: clock, reminders: reminders);
    await waitForSync(tester);

    await tester.tap(find.byKey(const Key('complete-Read')));
    await waitForSync(tester);

    expect(reminders.latest.first.when, DateTime(2026, 11, 10, 9, 30));
  });

  testWidgets('turning reminders off in Settings clears them', (tester) async {
    await seed(tester, reminder: '09:30');
    await pumpApp(tester, db, clock: clock, reminders: reminders);
    await waitForSync(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Habit reminders'));
    await waitForSync(tester);

    expect(reminders.latest, isEmpty);
  });

  testWidgets('setting a reminder in the editor asks for permission', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester, db, clock: clock, reminders: reminders);
    await tester.tap(find.text('Read'));
    await settle(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('reminder-value')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('reminder-value'))).data,
      'Off',
    );
    await tapVisible(tester, find.text('Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(reminders.permissionRequests, 1);
    expect(
      tester.widget<Text>(find.byKey(const Key('reminder-value'))).data,
      '9:00 AM',
    );

    await tester.tap(find.text('Save'));
    await waitForSync(tester);
    final habit = (await tester.runAsync(
      () => HabitRepository(db).getActiveHabits(),
    ))!.single;
    expect(habit.reminderTime, '09:00');
    expect(reminders.latest.first.when, DateTime(2026, 11, 9, 9));
  });

  testWidgets('a denied permission explains how to allow it', (tester) async {
    reminders.grantPermission = false;
    await seed(tester);
    await pumpApp(tester, db, clock: clock, reminders: reminders);
    await tester.tap(find.text('Read'));
    await settle(tester);

    await tapVisible(tester, find.text('Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.textContaining('Notifications are blocked'), findsOneWidget);
  });
}
