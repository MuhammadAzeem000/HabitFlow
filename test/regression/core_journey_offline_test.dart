import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// Any attempt to open a network connection fails the test.
class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw const SocketException('Network access attempted in offline test');
  }
}

/// HF-020: the plan's core journey, end to end, with the network blocked
/// ("airplane mode") and across an app restart.
void main() {
  late AppDatabase db;
  late _NoNetwork network;
  DateTime clock() => DateTime(2026, 11, 9, 9); // Monday

  setUp(() {
    db = createTestDatabase();
    network = _NoNetwork();
    HttpOverrides.global = network;
  });
  tearDown(() async {
    HttpOverrides.global = null;
    await db.close();
  });

  Future<List<HabitCompletion>> completions(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.habitCompletions).get()))!;

  Future<void> createHabit(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('New habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-name')), name);
    await tester.tap(find.text('Save'));
    await settle(tester);
  }

  testWidgets('create, edit, complete, rest, reorder, history, restart', (
    tester,
  ) async {
    await pumpApp(tester, db, clock: clock);
    expect(find.text('No habits yet'), findsOneWidget);

    // Create two habits from Today.
    await tester.tap(find.text('Create a habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-name')), 'Read');
    await tester.tap(find.text('Save'));
    await settle(tester);
    await createHabit(tester, 'Walk');
    expect(find.text('0 of 2 done'), findsOneWidget);

    // Edit: rename Walk.
    await tester.tap(find.text('Walk'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('habit-name')), 'Evening walk');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Evening walk'), findsOneWidget);

    // Complete one tap; undo; complete again.
    await tester.tap(find.byKey(const Key('complete-Read')));
    await tester.pump();
    expect(find.text('1 of 2 done'), findsOneWidget);
    await settle(tester);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('0 of 2 done'), findsOneWidget);
    await tester.tap(find.byKey(const Key('complete-Read')));
    await settle(tester);

    // Rest day for the walk: excluded from progress.
    await tester.longPress(find.text('Evening walk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a rest day'));
    await settle(tester);
    expect(find.text('1 of 1 done'), findsOneWidget);

    // Reorder on the Habits screen.
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
    final handle = find.byKey(const Key('drag-Evening walk'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -18));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);

    // History: the calendar reflects today.
    await tester.tap(find.text('Calendar'));
    await settle(tester);
    expect(find.bySemanticsLabel('November 9: 1 of 1 done'), findsOneWidget);

    // Restart the app on the same database: everything is kept.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, db, clock: clock);
    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(find.text('Rest day'), findsOneWidget);
    final walkY = tester.getTopLeft(find.text('Evening walk')).dy;
    final readY = tester.getTopLeft(find.text('Read')).dy;
    expect(walkY, lessThan(readY), reason: 'reorder survives restart');

    final stored = await completions(tester);
    expect(stored.map((c) => c.status).toSet(), {
      CompletionStatus.done,
      CompletionStatus.skipped,
    });

    // Nothing in the journey touched the network.
    expect(network.attempts, 0);
  });
}
