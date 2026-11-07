import 'dart:async';
import 'dart:io' show ProcessInfo;
import 'dart:ui' show FrameTiming, FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Bounded Flutter frame samples for on-device diagnostics. These are Flutter
/// view frames, NOT native MapLibre GPU frames; do not label them as such.
class FlutterFrameWindow {
  FlutterFrameWindow({this.capacity = 120}) : assert(capacity > 1);

  final int capacity;
  final List<double> _buildMs = <double>[];
  final List<double> _rasterMs = <double>[];
  final List<int> _vsyncMicros = <int>[];

  int get count => _buildMs.length;

  void add({required int vsyncMicros, required double buildMs,
      required double rasterMs}) {
    if (vsyncMicros < 0 || !buildMs.isFinite || !rasterMs.isFinite ||
        buildMs < 0 || rasterMs < 0) {
      return;
    }
    if (_vsyncMicros.isNotEmpty &&
        vsyncMicros <= _vsyncMicros.last) {
      return;
    }
    if (_buildMs.length == capacity) {
      _buildMs.removeAt(0);
      _rasterMs.removeAt(0);
      _vsyncMicros.removeAt(0);
    }
    _buildMs.add(buildMs);
    _rasterMs.add(rasterMs);
    _vsyncMicros.add(vsyncMicros);
  }

  static double? p95(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = List<double>.of(values)..sort();
    return sorted[(sorted.length * .95).ceil() - 1];
  }

  double? get buildP95Ms => p95(_buildMs);
  double? get rasterP95Ms => p95(_rasterMs);

  /// Actual submitted Flutter frames divided by observed VSYNC span.
  /// Sparse/idle pages yield a low number, not display hardware refresh Hz.
  double? get observedFlutterFps {
    if (_vsyncMicros.length < 3) return null;
    final elapsed = _vsyncMicros.last - _vsyncMicros.first;
    if (elapsed <= 0) return null;
    return ((_vsyncMicros.length - 1) * 1000000 / elapsed)
        .clamp(0.0, 240.0).toDouble();
  }

  void clear() {
    _buildMs.clear();
    _rasterMs.clear();
    _vsyncMicros.clear();
  }
}

/// Explicit opt-in, foreground-only performance sampling. No GPS coordinate,
/// bank data, trip receipt, network transmission or persistent storage.
class PerformanceMonitor extends ChangeNotifier {
  PerformanceMonitor({required this.isVisible}) {
    _startupClock.start();
  }

  final bool Function() isVisible;
  final Stopwatch _startupClock = Stopwatch();
  final FlutterFrameWindow _frames = FlutterFrameWindow();

  Timer? _sampleTimer;
  bool _monitoring = false;
  bool _overlayEnabled = false;
  bool _disposed = false;
  int? _firstFrameMs;
  int? _storageReadyMs;
  bool? _storageOk;
  int? _residentBytes;
  int _frameSamples = 0;

  bool get monitoring => _monitoring;
  bool get overlayEnabled => _overlayEnabled;
  int? get firstFrameMs => _firstFrameMs;
  int? get storageReadyMs => _storageReadyMs;
  bool? get storageOk => _storageOk;
  int? get residentBytes => _residentBytes;
  double? get uiBuildP95Ms => _frames.buildP95Ms;
  double? get rasterP95Ms => _frames.rasterP95Ms;
  double? get flutterFps => _frames.observedFlutterFps;
  int get frameSamples => _frameSamples;

  void markFirstFrame() {
    if (_disposed || _firstFrameMs != null) return;
    _firstFrameMs = _startupClock.elapsedMilliseconds;
    notifyListeners();
  }

  void markStorageFinished(Duration elapsed, {required bool successful}) {
    if (_disposed) return;
    _storageReadyMs = elapsed.inMilliseconds;
    _storageOk = successful;
    notifyListeners();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_disposed || !_monitoring || !isVisible()) return;
    for (final frame in timings) {
      _frames.add(
        vsyncMicros: frame.timestampInMicroseconds(FramePhase.vsyncStart),
        buildMs: frame.buildDuration.inMicroseconds / 1000,
        rasterMs: frame.rasterDuration.inMicroseconds / 1000,
      );
    }
    _frameSamples = _frames.count;
    // Avoid setState per frame; a 2-second timer refreshes the visible HUD.
  }

  void _sample() {
    if (_disposed || !_monitoring || !isVisible()) return;
    try {
      _residentBytes = ProcessInfo.currentRss;
    } catch (_) {
      _residentBytes = null;
    }
    notifyListeners();
  }

  void setMonitoring(bool enabled) {
    if (_disposed || enabled == _monitoring) return;
    _monitoring = enabled;
    if (enabled) {
      _frames.clear();
      _frameSamples = 0;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _sample();
      _sampleTimer = Timer.periodic(
          const Duration(seconds: 2), (_) => _sample());
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _sampleTimer?.cancel();
      _sampleTimer = null;
      _overlayEnabled = false;
    }
    notifyListeners();
  }

  void setOverlayEnabled(bool enabled) {
    if (_disposed) return;
    if (enabled && !_monitoring) setMonitoring(true);
    if (_overlayEnabled == enabled) return;
    _overlayEnabled = enabled;
    notifyListeners();
  }

  @override
  void dispose() {
    _overlayEnabled = false;
    if (_monitoring) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    _monitoring = false;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _frames.clear();
    _disposed = true;
    super.dispose();
  }
}
