import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/utilities/local_day.dart';

void main() {
  group('LocalDay', () {
    test('key is zero-padded ISO 8601 and round-trips', () {
      const day = LocalDay(2026, 3, 7);
      expect(day.key, '2026-03-07');
      expect(LocalDay.parse('2026-03-07'), day);
    });

    test('parse rejects malformed and impossible dates', () {
      expect(() => LocalDay.parse('2026-3-7'), throwsFormatException);
      expect(() => LocalDay.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDay.parse('nope'), throwsFormatException);
    });

    test('addDays crosses month, year and leap-day boundaries', () {
      expect(
        const LocalDay(2026, 1, 31).addDays(1),
        const LocalDay(2026, 2, 1),
      );
      expect(
        const LocalDay(2026, 12, 31).addDays(1),
        const LocalDay(2027, 1, 1),
      );
      expect(
        const LocalDay(2028, 2, 28).addDays(1),
        const LocalDay(2028, 2, 29),
      );
      expect(
        const LocalDay(2026, 3, 1).addDays(-1),
        const LocalDay(2026, 2, 28),
      );
    });

    test('day arithmetic is unaffected by DST transitions', () {
      // US DST starts 2026-03-08, EU DST ends 2026-10-25.
      expect(
        const LocalDay(2026, 3, 9).differenceInDays(const LocalDay(2026, 3, 7)),
        2,
      );
      expect(
        const LocalDay(2026, 10, 24).addDays(2),
        const LocalDay(2026, 10, 26),
      );
    });

    test('weekday is ISO (Mon=1, Sun=7)', () {
      expect(const LocalDay(2026, 11, 9).weekday, DateTime.monday);
      expect(const LocalDay(2026, 11, 8).weekday, DateTime.sunday);
    });

    test('fromDateTime uses the local date, ignoring time of day', () {
      expect(
        LocalDay.fromDateTime(DateTime(2026, 11, 8, 23, 59, 59)),
        const LocalDay(2026, 11, 8),
      );
      expect(
        LocalDay.fromDateTime(DateTime(2026, 11, 9)),
        const LocalDay(2026, 11, 9),
      );
    });

    test('ordering and keys sort consistently', () {
      const a = LocalDay(2026, 1, 9);
      const b = LocalDay(2026, 1, 10);
      expect(a.isBefore(b), isTrue);
      expect(a.key.compareTo(b.key), lessThan(0));
    });
  });
}
