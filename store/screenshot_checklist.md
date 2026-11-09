# Screenshot checklist

Play requires **2–8 phone screenshots**: PNG or JPEG, 16:9 or 9:16, each side
between 320 px and 3,840 px. Portrait **1080 × 2400** (or 1080 × 1920) from a
modern phone or emulator is ideal.

## Prepare realistic demo data

On a release build (light theme, phone language English):

1. Create 4–5 habits with different icons/colours and schedules, e.g.
   *Drink water* (every day), *Read 10 pages* (every day, reminder 21:30),
   *Gym* (Mon/Wed/Fri), *Meditate* (3× per week), *Stretch* (weekdays).
2. Complete a few habits on several earlier days so streaks, the calendar and
   weekly consistency look lived-in. (Change the device date temporarily, or
   use the app normally for a few days.)
3. Start a 30-day challenge for one habit.
4. Leave 1–2 habits not yet done today, so the Today screen shows progress.

## Shots (in listing order)

| # | Screen | What it should show | Caption idea |
|---|---|---|---|
| 1 | Today | Progress card ("3 of 5 done"), streaks on cards, challenge strip | One tap to check in |
| 2 | Today, just after a tap | A habit ticked with the Undo snackbar | Instant, with undo |
| 3 | Habit editor | Icon/colour pickers, schedule, reminder | Your habits, your schedule |
| 4 | Calendar | A month with filled days | See your progress |
| 5 | Habit stats (edit screen top) | Current / best streak, this week | Streaks without pressure |
| 6 | Long-press menu | Rest day / Pause options | Rest days don't break streaks |
| 7 | 30-day challenge | Progress bar, "Free" label | Free 30-day challenge |
| 8 | Dark theme | Today in dark mode | Light and dark themes |

## Capture

With the phone connected (USB debugging) or the emulator running:

```sh
adb shell screencap -p /sdcard/shot.png
adb pull /sdcard/shot.png store/screenshots/01_today.png
```

(In Git Bash, prefix with `MSYS_NO_PATHCONV=1` so `/sdcard/...` isn't rewritten.)

Before capturing: hide the debug banner (release build), set the status bar
to a clean state (full battery, no stray notifications), and use real-looking
habit names.

## Optional

- **Tablet screenshots:** only needed to target tablets in the listing.
- **Promo video:** a YouTube link, optional.
