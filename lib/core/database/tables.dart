import 'package:drift/drift.dart';

import 'enums.dart';

// Calendar days are stored as ISO 8601 `yyyy-MM-dd` text (see LocalDay.key),
// timestamps as ISO 8601 date-time text (build.yaml option).

@DataClassName('Habit')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();

  /// ARGB hex, e.g. `ff2e7d6b`.
  TextColumn get color => text().nullable()();

  /// Current schedule. History lives in [HabitSchedules].
  TextColumn get frequency => textEnum<HabitFrequency>()();

  /// Comma-separated ISO weekdays (1 = Mon … 7 = Sun) for `weekdays`.
  TextColumn get targetDays => text().nullable()();

  /// Completions per week for `weeklyTarget`.
  IntColumn get weeklyTarget => integer().nullable()();

  /// Local time `HH:mm`.
  TextColumn get reminderTime => text().nullable()();
  TextColumn get startDate => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Paused through this day (inclusive); paused days are never misses.
  TextColumn get pausedUntil => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HabitCompletion')
@TableIndex(name: 'idx_completions_date', columns: {#completionDate})
class HabitCompletions extends Table {
  TextColumn get id => text()();
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get completionDate => text()();
  TextColumn get status => textEnum<CompletionStatus>().withDefault(
    Constant(CompletionStatus.done.name),
  )();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, completionDate},
  ];
}

/// Schedule versions, so editing a schedule never rewrites past history.
/// The schedule for a day is the entry with the latest `effective_from`
/// on or before that day (falling back to the earliest entry).
@DataClassName('HabitScheduleEntry')
class HabitSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get effectiveFrom => text()();
  TextColumn get frequency => textEnum<HabitFrequency>()();
  TextColumn get targetDays => text().nullable()();
  IntColumn get weeklyTarget => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, effectiveFrom},
  ];
}

@DataClassName('Challenge')
class Challenges extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get habitId =>
      text().nullable().references(Habits, #id, onDelete: KeyAction.setNull)();
  IntColumn get durationDays => integer().withDefault(const Constant(30))();
  TextColumn get startDate => text()();
  TextColumn get status => textEnum<ChallengeStatus>().withDefault(
    Constant(ChallengeStatus.active.name),
  )();
  TextColumn get pausedOn => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UserSetting')
class UserSettings extends Table {
  TextColumn get id => text()();
  TextColumn get timeFormat => textEnum<TimeFormatPreference>().withDefault(
    Constant(TimeFormatPreference.system.name),
  )();
  TextColumn get theme => textEnum<ThemePreference>().withDefault(
    Constant(ThemePreference.system.name),
  )();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
