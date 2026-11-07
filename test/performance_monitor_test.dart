import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/performance_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frame p95, bounded samples and Flutter FPS are calculated correctly', () {
    final window = FlutterFrameWindow(capacity: 120);
    for (var i = 0; i < 120; i++) {
      window.add(vsyncMicros: i * 16667,
        buildMs: (i + 1).toDouble(), rasterMs: 8);
    }
    expect(window.count, 120);
    expect(window.buildP95Ms, 114);
    expect(window.rasterP95Ms, 8);
    expect(window.observedFlutterFps!, closeTo(60.0, .1));

    for (var i = 120; i < 200; i++) {
      window.add(vsyncMicros: i * 16667, buildMs: 3, rasterMs: 4);
    }
    expect(window.count, 120);
    expect(window.observedFlutterFps!, closeTo(60.0, .1));
    expect(window.buildP95Ms, 114,
      reason: 'Only the last 120 accepted frames contribute to the sample');
    window.clear();
    expect(window.count, 0);
    expect(window.buildP95Ms, isNull);
    expect(window.observedFlutterFps, isNull);
  });

  test('rejects malformed/duplicate samples without growing memory', () {
    final window = FlutterFrameWindow(capacity: 3);
    window.add(vsyncMicros: 1000000, buildMs: 5, rasterMs: 2);
    window.add(vsyncMicros: 1000000, buildMs: 7, rasterMs: 2);
    window.add(vsyncMicros: 2000000, buildMs: double.nan, rasterMs: 2);
    window.add(vsyncMicros: 3000000, buildMs: 5, rasterMs: 2);
    expect(window.count, 2);
    expect(window.observedFlutterFps, isNull);
    window.add(vsyncMicros: 4000000, buildMs: 5, rasterMs: 2);
    expect(window.count, 3);
    window.add(vsyncMicros: 5000000, buildMs: 5, rasterMs: 2);
    expect(window.count, 3);
    expect(window.observedFlutterFps, closeTo(1, .0001));
  });

  test('startup measurements exist independently of optional monitoring', () {
    final monitor = PerformanceMonitor(isVisible: () => true);
    expect(monitor.monitoring, isFalse);
    expect(monitor.firstFrameMs, isNull);
    monitor.markFirstFrame();
    final first = monitor.firstFrameMs;
    expect(first, isNotNull);
    monitor.markFirstFrame();
    expect(monitor.firstFrameMs, first);
    monitor.markStorageFinished(const Duration(milliseconds: 1360),
      successful: true);
    expect(monitor.storageReadyMs, 1360);
    expect(monitor.storageOk, isTrue);
    monitor.dispose();
  });

  test('opt-in HUD disables monitoring and releases scheduler subscriptions', () {
    final monitor = PerformanceMonitor(isVisible: () => true);
    expect(monitor.monitoring, isFalse);
    monitor.setOverlayEnabled(true);
    expect(monitor.monitoring, isTrue);
    expect(monitor.overlayEnabled, isTrue);
    monitor.setMonitoring(false);
    expect(monitor.monitoring, isFalse);
    expect(monitor.overlayEnabled, isFalse);
    monitor.setMonitoring(false);
    monitor.dispose();
  });
}
