import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_day.dart';

/// Source of "now". Overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Today's date in device-local time. Rolls over at local midnight and is
/// re-checked whenever the app returns to the foreground (covers timezone
/// changes and devices that slept through midnight).
final currentDayProvider = NotifierProvider<CurrentDay, LocalDay>(
  CurrentDay.new,
);

class CurrentDay extends Notifier<LocalDay> {
  Timer? _midnightTimer;
  AppLifecycleListener? _lifecycle;

  @override
  LocalDay build() {
    final clock = ref.watch(clockProvider);
    _lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _midnightTimer?.cancel();
      _lifecycle?.dispose();
    });
    _scheduleRollover(clock);
    return LocalDay.today(clock);
  }

  /// Re-reads the clock; updates listeners only if the date changed.
  void refresh() {
    final today = LocalDay.today(ref.read(clockProvider));
    if (today != state) state = today;
  }

  void _scheduleRollover(DateTime Function() clock) {
    _midnightTimer?.cancel();
    final now = clock();
    final nextMidnight = LocalDay.fromDateTime(now).addDays(1).startOfDay;
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        refresh();
        _scheduleRollover(clock);
      },
    );
  }
}
