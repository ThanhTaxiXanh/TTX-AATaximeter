/// Bounded, in-memory SQL query timings for on-phone QA.
/// No GPS coordinates, addresses, trip identities or fare data are recorded.
class TrafficSignQueryMetrics {
  TrafficSignQueryMetrics({this.capacity = 64})
      : assert(capacity > 0);

  final int capacity;
  final List<int> _microseconds = <int>[];
  int _queries = 0;
  int _failures = 0;

  int get queryCount => _queries;
  int get failureCount => _failures;
  int get sampleCount => _microseconds.length;

  void record(Duration elapsed, {required bool succeeded}) {
    _queries++;
    if (!succeeded) {
      _failures++;
      return;
    }
    if (_microseconds.length == capacity) _microseconds.removeAt(0);
    _microseconds.add(elapsed.inMicroseconds.clamp(0, 0x7fffffff));
  }

  double? get p50Ms => _percentileMs(0.50);
  double? get p95Ms => _percentileMs(0.95);

  double? _percentileMs(double percentile) {
    if (_microseconds.isEmpty) return null;
    final ordered = List<int>.of(_microseconds)..sort();
    final index = ((ordered.length * percentile).ceil() - 1)
        .clamp(0, ordered.length - 1);
    return ordered[index] / 1000.0;
  }

  /// Useful on a production-size Android device without developer options.
  String get summary {
    if (_microseconds.isEmpty) {
      return 'SQLite: $_queries truy vấn, chưa có mẫu thành công'
          '${_failures > 0 ? ', lỗi $_failures' : ''}';
    }
    return 'SQLite: $_queries truy vấn · p50 '
        '${p50Ms!.toStringAsFixed(1)} ms · p95 '
        '${p95Ms!.toStringAsFixed(1)} ms'
        '${_failures > 0 ? ' · lỗi $_failures' : ''}';
  }
}
