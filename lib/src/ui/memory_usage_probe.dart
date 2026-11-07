import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart';

/// A bounded process RSS window. Uses integers and never retains the
/// application's GPS, map, receipts, frames, or other user data.
class RssSampleWindow {
  RssSampleWindow({this.capacity = 10})
      : assert(capacity > 0);

  final int capacity;
  final List<int> _samples = [];

  int get count => _samples.length;
  int get lastBytes => _samples.isEmpty ? 0 : _samples.last;
  int get maximumBytes => _samples.isEmpty
      ? 0 : _samples.reduce((a, b) => a > b ? a : b);
  int get minimumBytes => _samples.isEmpty
      ? 0 : _samples.reduce((a, b) => a < b ? a : b);

  void record(int residentBytes) {
    if (residentBytes < 0) return;
    if (_samples.length == capacity) _samples.removeAt(0);
    _samples.add(residentBytes);
  }

  void clear() => _samples.clear();
}

/// Approximate Android process resident memory, including most native
/// MapLibre pages. This does NOT include all GPU memory or measure a leak.
/// Only samples in Debug/Profile foreground mode, every 30s by default.
class MemoryUsageProbe {
  MemoryUsageProbe({
    required this.isVisible,
    this.interval = const Duration(seconds: 30),
  });

  final bool Function() isVisible;
  final Duration interval;
  final RssSampleWindow _samples = RssSampleWindow();
  Timer? _timer;

  void start() {
    if (kReleaseMode || _timer != null) return;
    _timer = Timer.periodic(interval, (_) {
      if (!isVisible()) return;
      try {
        _samples.record(ProcessInfo.currentRss);
        if (_samples.count < _samples.capacity) return;
        String mb(int bytes) => (bytes / 1e6).toStringAsFixed(1);
        debugPrint('TTX_PERF process_rss_mb=${mb(_samples.lastBytes)} '
            'rss_window_min_mb=${mb(_samples.minimumBytes)} '
            'rss_window_max_mb=${mb(_samples.maximumBytes)} '
            'mode=${kProfileMode ? 'profile' : 'debug'}');
      } catch (error) {
        // Diagnostics are NEVER allowed to affect GPS/fare state.
        assert(() {
          debugPrint('TTX_PERF memory probe unavailable: $error');
          return true;
        }());
        stop();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _samples.clear();
  }
}
