import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/ads/ad_policy.dart';
import 'package:habitflow/core/ads/ad_service.dart';
import 'package:habitflow/core/ads/ad_slot.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Returns a visible fake banner, or behaves badly on purpose.
class _FakeAdService implements AdService {
  _FakeAdService({this.mode = _Mode.banner});

  final _Mode mode;
  int requests = 0;

  @override
  Future<Widget?> loadBanner(AdPlacement placement) {
    requests++;
    return switch (mode) {
      _Mode.banner => Future.value(Text('AD ${placement.name}')),
      _Mode.hang => Completer<Widget?>().future,
      _Mode.fail => Future.error(Exception('no fill')),
    };
  }
}

enum _Mode { banner, hang, fail }

void main() {
  group('AdPolicy', () {
    const later = Duration(minutes: 1);

    test('never for Plus subscribers', () {
      for (final p in AdPlacement.values) {
        expect(
          AdPolicy.canShow(
            p,
            const AdContext(isPlus: true, sinceLaunch: later),
          ),
          isFalse,
        );
      }
    });

    test('never at launch', () {
      for (final p in AdPlacement.values) {
        expect(
          AdPolicy.canShow(
            p,
            const AdContext(isPlus: false, sinceLaunch: Duration(seconds: 3)),
          ),
          isFalse,
        );
      }
    });

    test('allowed placements after the launch grace period', () {
      for (final p in AdPlacement.values) {
        expect(
          AdPolicy.canShow(
            p,
            const AdContext(isPlus: false, sinceLaunch: later),
          ),
          isTrue,
        );
      }
    });

    test('no placement exists for Today, launch, completion or challenges', () {
      final names = AdPlacement.values.map((p) => p.name.toLowerCase());
      for (final forbidden in [
        'today',
        'home',
        'launch',
        'complet',
        'challenge',
        'editor',
        'interstitial',
      ]) {
        expect(
          names.any((n) => n.contains(forbidden)),
          isFalse,
          reason: forbidden,
        );
      }
    });
  });

  group('AdSlot in the app', () {
    late AppDatabase db;
    DateTime clock() => DateTime(2026, 11, 9, 9);

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    Future<void> seed(WidgetTester tester) => tester.runAsync(
      () => HabitRepository(db).createHabit(
        const HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.daily,
          startDate: LocalDay(2026, 11, 1),
        ),
      ),
    );

    Future<void> pump(
      WidgetTester tester,
      AdService ads, {
      bool plus = false,
      Duration sinceLaunch = const Duration(minutes: 5),
    }) => pumpApp(
      tester,
      db,
      clock: clock,
      extraOverrides: [
        adServiceProvider.overrideWithValue(ads),
        isPlusProvider.overrideWithValue(plus),
        sinceLaunchProvider.overrideWithValue(() => sinceLaunch),
      ],
    );

    testWidgets('Today never contains an ad slot', (tester) async {
      await seed(tester);
      await pump(tester, _FakeAdService());
      expect(find.byType(AdSlot), findsNothing);
      expect(find.textContaining('AD '), findsNothing);
    });

    testWidgets('a banner appears on an allowed screen once loaded', (
      tester,
    ) async {
      await seed(tester);
      await pump(tester, _FakeAdService());
      await tester.tap(find.text('Habits'));
      await settle(tester);
      expect(find.text('AD habitsListFooter'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Advertisement')), findsOneWidget);
    });

    testWidgets('no ad for Plus, and none is even requested', (tester) async {
      final ads = _FakeAdService();
      await seed(tester);
      await pump(tester, ads, plus: true);
      await tester.tap(find.text('Habits'));
      await settle(tester);
      expect(find.textContaining('AD '), findsNothing);
      expect(ads.requests, 0);
    });

    testWidgets('no ad right after launch', (tester) async {
      final ads = _FakeAdService();
      await seed(tester);
      await pump(tester, ads, sinceLaunch: const Duration(seconds: 2));
      await tester.tap(find.text('Habits'));
      await settle(tester);
      expect(find.textContaining('AD '), findsNothing);
      expect(ads.requests, 0);
    });

    testWidgets('a hanging ad never blocks the app or completion', (
      tester,
    ) async {
      await seed(tester);
      await pump(tester, _FakeAdService(mode: _Mode.hang));
      await tester.tap(find.text('Habits'));
      await settle(tester);
      expect(find.textContaining('AD '), findsNothing);

      await tester.tap(find.text('Today'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('complete-Read')));
      await tester.pump();
      expect(find.text('1 of 1 done'), findsOneWidget);

      await settle(tester);
      final stored = (await tester.runAsync(
        () => db.select(db.habitCompletions).get(),
      ))!;
      expect(stored.single.status, CompletionStatus.done);
      // The slot gives up on the hanging ad after its 15 s timeout.
      await tester.pump(const Duration(seconds: 16));
    });

    testWidgets('a failing ad shows nothing and does not crash', (
      tester,
    ) async {
      await seed(tester);
      await pump(tester, _FakeAdService(mode: _Mode.fail));
      await tester.tap(find.text('Calendar'));
      await settle(tester);
      expect(find.textContaining('AD '), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
