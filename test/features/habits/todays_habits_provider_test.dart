import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/database/database_providers.dart';
import 'package:habitflow/core/utilities/current_day.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/application/habit_providers.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';

import '../../helpers/test_container.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late ProviderContainer container;

  Future<String> create(
    String name, {
    HabitFrequency frequency = HabitFrequency.daily,
    List<int> days = const [],
    String start = '2026-11-01',
  }) => container
      .read(habitRepositoryProvider)
      .createHabit(
        HabitDraft(
          name: name,
          frequency: frequency,
          targetDays: days,
          startDate: LocalDay.parse(start),
        ),
      );

  Future<List<String>> todaysNames() async {
    // Keep the provider alive between reads.
    final sub = container.listen(todaysHabitsProvider, (_, _) {});
    addTearDown(sub.close);
    final list = await readAsyncData(container, todaysHabitsProvider);
    return list.map((h) => h.name).toList();
  }

  setUp(() {
    db = createTestDatabase();
    now = DateTime(2026, 11, 9, 10); // Monday
    container = createTestContainer(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('lists only habits scheduled today, in user order', () async {
    await create('Daily');
    await create('Mon/Wed', frequency: HabitFrequency.weekdays, days: [1, 3]);
    await create('Tue only', frequency: HabitFrequency.weekdays, days: [2]);
    await create('Starts later', start: '2026-11-20');

    expect(await todaysNames(), ['Daily', 'Mon/Wed']);
  });

  test('excludes paused and archived habits', () async {
    final paused = await create('Paused');
    final archived = await create('Archived');
    await create('Active');
    final repo = container.read(habitRepositoryProvider);
    await repo.pause(
      paused,
      from: const LocalDay(2026, 11, 9),
      until: const LocalDay(2026, 11, 9),
    );
    await repo.setArchived(archived, archived: true);

    expect(await todaysNames(), ['Active']);
  });

  test('re-evaluates when the day changes', () async {
    await create('Tue only', frequency: HabitFrequency.weekdays, days: [2]);
    expect(await todaysNames(), isEmpty);

    now = DateTime(2026, 11, 10, 0, 0, 5); // Tuesday
    container.read(currentDayProvider.notifier).refresh();

    expect(await todaysNames(), ['Tue only']);
  });

  test('a schedule edit today applies today', () async {
    final id = await create('Read');
    await container
        .read(habitRepositoryProvider)
        .updateHabit(
          id,
          const HabitDraft(
            name: 'Read',
            frequency: HabitFrequency.weekdays,
            targetDays: [2],
            startDate: LocalDay(2026, 11, 1),
          ),
        );
    expect(await todaysNames(), isEmpty);
  });
}
