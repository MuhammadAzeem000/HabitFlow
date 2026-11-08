import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/database/app_database.dart';
import 'package:habitflow/core/utilities/local_day.dart';
import 'package:habitflow/features/habits/data/habit_repository.dart';
import 'package:habitflow/features/habits/domain/habit_draft.dart';
import 'package:habitflow/features/tracking/data/completion_repository.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('habitflow'));
  tearDown(() => dir.delete(recursive: true));

  test(
    'habits and completions survive closing and reopening the database',
    () async {
      final file = File('${dir.path}/habitflow.sqlite');

      final first = AppDatabase(NativeDatabase(file));
      final id = await HabitRepository(first).createHabit(
        const HabitDraft(
          name: 'Read',
          frequency: HabitFrequency.weekdays,
          targetDays: [1, 3],
          startDate: LocalDay(2026, 11, 1),
        ),
      );
      await CompletionRepository(first).mark(id, const LocalDay(2026, 11, 9));
      await first.close();

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final habit = await HabitRepository(reopened).getHabit(id);
      expect(habit?.name, 'Read');
      expect(habit?.targetDays, '1,3');
      expect(
        await CompletionRepository(reopened).getForHabit(id),
        hasLength(1),
      );
    },
  );
}
