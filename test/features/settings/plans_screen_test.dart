import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/features/settings/domain/plans.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> openPlans(WidgetTester tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Free & Plus'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists free-forever features and the core promise', (
    tester,
  ) async {
    await openPlans(tester);

    expect(find.textContaining('history will never be locked'), findsOneWidget);
    for (final f in freeForeverFeatures) {
      await tester.scrollUntilVisible(
        find.text(f.title),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(f.title), findsOneWidget);
    }
  });

  testWidgets('future premium ideas are clearly labelled, not sold', (
    tester,
  ) async {
    await openPlans(tester);

    await tester.scrollUntilVisible(
      find.text('There is nothing to buy right now.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Coming later'),
      findsNWidgets(plannedPlusFeatures.length),
    );
    expect(
      find.textContaining('price and any trial terms will be shown'),
      findsOneWidget,
    );
    // No purchase flow exists.
    for (final word in ['Buy', 'Subscribe', 'Upgrade', 'Start trial']) {
      expect(find.text(word), findsNothing, reason: word);
    }
  });

  test('the free challenge and history are on the free-forever list', () {
    final titles = freeForeverFeatures.map((f) => f.title);
    expect(titles, contains('30-day challenge'));
    expect(titles, contains('Your full history'));
  });
}
