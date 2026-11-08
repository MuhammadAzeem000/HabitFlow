import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/time_format.dart';
import 'package:habitflow/features/settings/data/settings_repository.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  group('stored time', () {
    test('round-trips HH:mm', () {
      const t = TimeOfDay(hour: 7, minute: 5);
      expect(toStoredTime(t), '07:05');
      expect(parseStoredTime('07:05'), t);
      expect(parseStoredTime('21:30'), const TimeOfDay(hour: 21, minute: 30));
    });

    test('rejects malformed values', () {
      for (final bad in [null, '', '7', '24:00', '12:60', 'ab:cd']) {
        expect(parseStoredTime(bad), isNull, reason: '$bad');
      }
    });
  });

  group('TimeFormatScope', () {
    Future<String> formatted(
      WidgetTester tester,
      TimeFormatPreference pref, {
      required bool device24h,
    }) async {
      late String result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(alwaysUse24HourFormat: device24h),
          child: MaterialApp(
            home: TimeFormatScope(
              preference: pref,
              child: Builder(
                builder: (context) {
                  result = formatTime(
                    context,
                    const TimeOfDay(hour: 21, minute: 30),
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      return result;
    }

    testWidgets('system follows the device setting', (tester) async {
      expect(
        await formatted(tester, TimeFormatPreference.system, device24h: false),
        '9:30 PM',
      );
      expect(
        await formatted(tester, TimeFormatPreference.system, device24h: true),
        '21:30',
      );
    });

    testWidgets('manual override wins over the device', (tester) async {
      expect(
        await formatted(tester, TimeFormatPreference.h24, device24h: false),
        '21:30',
      );
      expect(
        await formatted(tester, TimeFormatPreference.h12, device24h: true),
        '9:30 PM',
      );
    });
  });

  group('Settings screen', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    testWidgets('choosing 24-hour applies instantly and persists', (
      tester,
    ) async {
      await pumpApp(tester, db);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('time-format-example'))).data,
        contains('9:30 PM'),
      );

      await tester.tap(find.text('24-hour'));
      await settle(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('time-format-example'))).data,
        'e.g. 21:30',
      );
      final saved = await tester.runAsync(() => SettingsRepository(db).load());
      expect(saved!.timeFormat, TimeFormatPreference.h24);
    });
  });
}
