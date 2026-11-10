# QA checklist

Run before every release candidate. Automated checks run in CI on every PR;
the manual section needs a real Android phone (or emulator) and a **release**
build: `flutter build apk --release`.

## 1. Automated coverage (CI)

| MVP release checklist item | Covered by |
|---|---|
| Home loads from local data, no network or ads | `test/regression/core_journey_offline_test.dart` (network blocked), `test/regression/offline_first_guard_test.dart`, `test/core/ads/ad_safety_test.dart` |
| Completion updates immediately and works offline | `test/features/dashboard/instant_completion_test.dart`, core journey test |
| Create/edit/reorder preserve data and history | `test/features/habits/*`, core journey test |
| Streak and consistency calculations | `test/features/tracking/streak_test.dart`, `consistency_test.dart` |
| Rest days and paused habits | `test/features/tracking/rest_and_pause_test.dart`, streak/consistency tests |
| System time format respected | `test/features/settings/time_format_test.dart` |
| Notifications permission-aware | `test/core/notifications/*` |
| No startup or completion-gated ad | `test/core/ads/ad_safety_test.dart` |
| Free 30-day challenge completable without payment | `test/features/challenges/challenge_test.dart` |
| Database upgrades keep data | `test/drift/app_database/migration_test.dart` |

## 2. Manual checks on a device

Install the release build **over the previous release** (to exercise the
database migration), then:

- [ ] **Upgrade:** existing habits, history and settings are still there.
- [ ] **Airplane mode on:** create a habit, edit it, complete it, undo it,
      reorder habits, open Calendar — everything works.
- [ ] **Restart** (swipe the app away, reopen): all of the above is kept.
- [ ] **Cold start feels fast** (no spinner, no blank wait beyond the launch
      screen). Optional: `adb shell am start -S -W -n com.habitflow.productivity/.MainActivity`
      and note `TotalTime`.
- [ ] **Completion:** the tick appears instantly; a fast double tap counts
      once.
- [ ] **Reminder:** set a reminder 2–3 minutes ahead; the permission prompt
      appears the first time; the notification arrives (Android may deliver
      it a minute or two late). Completing the habit first cancels today's
      reminder.
- [ ] **Reboot the phone:** future reminders still arrive.
- [ ] **12/24-hour:** with the phone set to 24-hour, times show as 24-hour;
      the Settings override changes them immediately.
- [ ] **Rest day and pause:** neither breaks the streak; pausing a habit
      already done today keeps today done.
- [ ] **30-day challenge:** start, tick, pause, restart, end — no payment
      prompt anywhere.
- [ ] **Free & Plus:** wording is accurate; nothing can be bought.
- [ ] **Dark mode and large text** (Settings → Display → Font size: largest):
      no clipped or overlapping text on Today, Habits, editor, Calendar.
- [ ] **TalkBack:** Today's habits and the completion button are announced
      sensibly.

## 3. Sign-off

Record the build version (`pubspec.yaml`), device, Android version, date
and any issues in the release PR.
