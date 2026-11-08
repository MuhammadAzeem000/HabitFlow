import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Local-only performance markers (HF-019).
///
/// Durations are written to the Flutter Timeline (visible in DevTools) and,
/// outside release builds, to the debug log. Nothing is sent anywhere and
/// no habit data is recorded — only phase names and durations.
class StartupMetrics {
  StartupMetrics([Stopwatch? stopwatch])
    : _stopwatch = stopwatch ?? (Stopwatch()..start());

  final Stopwatch _stopwatch;
  final List<(String, Duration)> _marks = [];

  /// Records that [phase] finished now (time since `main` started).
  void mark(String phase) {
    final at = _stopwatch.elapsed;
    _marks.add((phase, at));
    developer.Timeline.instantSync(
      'startup:$phase',
      arguments: {'ms': at.inMilliseconds},
    );
  }

  List<(String, Duration)> get marks => List.unmodifiable(_marks);

  /// e.g. "startup: database+settings 42 ms · first frame 180 ms".
  String summary() =>
      'startup: ${_marks.map((m) => '${m.$1} ${m.$2.inMilliseconds} ms').join(' · ')}';

  void report() {
    if (!kReleaseMode) debugPrint(summary());
  }
}

/// Times one habit completion from tap to stored (debug/profile only).
class CompletionTimer {
  CompletionTimer(this.label) : _stopwatch = Stopwatch()..start();

  final String label;
  final Stopwatch _stopwatch;

  /// Logs how long the local write took. [label] must not contain habit
  /// names or other personal data.
  void stored() {
    final ms = _stopwatch.elapsedMilliseconds;
    developer.Timeline.instantSync(
      'completion:stored',
      arguments: {'ms': ms, 'kind': label},
    );
    if (!kReleaseMode) debugPrint('completion ($label) stored in $ms ms');
  }
}
