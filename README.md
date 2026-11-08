# HabitFlow

A fast, reliable, offline-first habit tracker built with Flutter. Android first.

**Core promise:** open the app, see today's habits, tap one complete, leave in
seconds. Habit completion never waits on an ad, a network request, or a sign-in.

## Stack

| Layer | Choice |
|---|---|
| State | Riverpod 3 |
| Navigation | GoRouter (`StatefulShellRoute`, 4 tabs) |
| Database | SQLite via Drift (background isolate) — the source of truth |
| Backend | None for MVP |

## Project layout

```
lib/
├── main.dart                 # local-first launch: open DB, read settings, runApp
├── app/                      # app widget, router, theme
├── core/
│   ├── database/             # Drift tables, enums, AppDatabase, providers
│   └── utilities/            # LocalDay (device-local calendar days)
├── features/
│   ├── dashboard/            # Today screen
│   ├── habits/               # habit domain, repository, screens
│   ├── tracking/             # completions repository
│   ├── calendar/
│   ├── challenges/
│   └── settings/
└── shared/widgets/
drift_schemas/                # schema snapshots per version (for migrations)
test/
```

## Data model

Tables: `habits`, `habit_completions`, `habit_schedules`, `challenges`,
`user_settings`.

- Calendar days are stored as `yyyy-MM-dd` text in **device-local** time
  (`LocalDay`); timestamps are ISO 8601 text.
- `habit_completions` has one row per habit per day (`UNIQUE(habit_id,
  completion_date)`), with `status` = `done` or `skipped` (planned rest day).
- `habit_schedules` versions a habit's schedule, so editing it never rewrites
  past history.
- Archive keeps history; delete removes the habit and its history (cascade).

## Common commands

```sh
flutter pub get
dart run build_runner build          # regenerate Drift code after table changes
flutter analyze
flutter test
flutter run
```

### Changing the database schema

1. Edit `lib/core/database/tables.dart` and bump `schemaVersion`.
2. `dart run build_runner build`
3. `dart run drift_dev make-migrations` — snapshots the schema and generates
   migration helpers and tests under `test/drift/`.
4. Implement the step in `AppDatabase.migration.onUpgrade` and run the tests.
