import 'package:flutter_test/flutter_test.dart';
import 'package:habitflow/core/utilities/perf_metrics.dart';

class _FakeStopwatch implements Stopwatch {
  Duration now = Duration.zero;

  @override
  Duration get elapsed => now;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('records phases in order with their time since launch', () {
    final clock = _FakeStopwatch();
    final metrics = StartupMetrics(clock);

    clock.now = const Duration(milliseconds: 42);
    metrics.mark('database+settings');
    clock.now = const Duration(milliseconds: 180);
    metrics.mark('first frame');

    expect(metrics.marks.map((m) => m.$1), [
      'database+settings',
      'first frame',
    ]);
    expect(
      metrics.summary(),
      'startup: database+settings 42 ms · first frame 180 ms',
    );
  });

  test('completion timer labels carry no habit data', () {
    // Labels are status names only (done / skipped / cleared).
    expect(() => CompletionTimer('done').stored(), returnsNormally);
  });
}
