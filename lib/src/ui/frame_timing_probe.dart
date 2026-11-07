import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Observes UI/raster timing without changing any trip state. Never enabled
/// in release APKs, and never writes personal GPS or receipts to disk.
class FrameTimingProbe {
  FrameTimingProbe({this.sampleSize = 120});

  final int sampleSize;
  final List<double> _buildMs = <double>[];
  final List<double> _rasterMs = <double>[];
  bool _started = false;

  static double percentile95(List<double> samples) {
    if (samples.isEmpty) return 0;
    final sorted = List<double>.of(samples)..sort();
    final index = (sorted.length * 0.95).ceil() - 1;
    final bounded = index < 0 ? 0 :
        (index >= sorted.length ? sorted.length - 1 : index);
    return sorted[bounded];
  }

  void start() {
    if (kReleaseMode || _started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_record);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    SchedulerBinding.instance.removeTimingsCallback(_record);
    _buildMs.clear();
    _rasterMs.clear();
  }

  void _record(List<FrameTiming> frames) {
    for (final frame in frames) {
      _buildMs.add(frame.buildDuration.inMicroseconds / 1000);
      _rasterMs.add(frame.rasterDuration.inMicroseconds / 1000);
      if (_buildMs.length < sampleSize) continue;
      final buildP95 = percentile95(_buildMs).toStringAsFixed(1);
      final rasterP95 = percentile95(_rasterMs).toStringAsFixed(1);
      debugPrint('TTX_PERF frame_samples=${_buildMs.length} '
        'build_p95_ms=$buildP95 raster_p95_ms=$rasterP95 '
        'mode=${kProfileMode ? 'profile' : 'debug'}');
      _buildMs.clear();
      _rasterMs.clear();
    }
  }
}
