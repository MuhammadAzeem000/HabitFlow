import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CompletionRepository completions;
  late String habitId;
  const day = LocalDay(2026, 11, 8);

  setUp(() async {
    db = createTestDatabase();
    completions = CompletionRepository(db);
    habitId = await HabitRepository(db).createHabit(
      const HabitDraft(
        name: 'Read',
        frequency: HabitFrequency.daily,
        startDate: LocalDay(2026, 11, 1),
      ),
    );
  });
  tearDown(() => db.close());

  test('repeated marks never create duplicate records', () async {
    await Future.wait([
      completions.mark(habitId, day),
      completions.mark(habitId, day),
      completions.mark(habitId, day),
    ]);
    await completions.mark(habitId, day);

    final rows = await completions.getForHabit(habitId);
    expect(rows, hasLength(1));
    expect(rows.single.status, CompletionStatus.done);
  });

  test('marking a rest day replaces a completion on the same day', () async {
    await completions.mark(habitId, day);
    await completions.mark(habitId, day, status: CompletionStatus.skipped);

    final rows = await completions.getForHabit(habitId);
    expect(rows, hasLength(1));
    expect(rows.single.status, CompletionStatus.skipped);
  });

  test('clear removes only that day (undo)', () async {
    await completions.mark(habitId, day);
    await completions.mark(habitId, day.addDays(-1));

    await completions.clear(habitId, day);

    final rows = await completions.getForHabit(habitId);
    expect(rows.map((r) => r.completionDate), ['2026-11-07']);
  });

  test('range query is inclusive', () async {
    for (var i = 0; i < 5; i++) {
      await completions.mark(habitId, day.addDays(-i));
    }
    final rows = await completions
        .watchForRange(day.addDays(-3), day.addDays(-1))
        .first;
    expect(rows.map((r) => r.completionDate).toList()..sort(), [
      '2026-11-05',
      '2026-11-06',
      '2026-11-07',
    ]);
  });

  test('completions cannot reference a missing habit', () async {
    expect(() => completions.mark('missing', day), throwsA(isA<Exception>()));
  });
}
