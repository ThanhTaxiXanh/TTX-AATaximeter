import 'dart:math' as math;

import '../domain/trip_route_point.dart';

/// Read-only visual geometry. Never pass these simplified points into the
/// taximeter, SQLite checkpoints, GPS validation, or completed trip receipts.
/// Each segment preserves its original endpoints and all sufficiently sharp
/// bends; no synthetic GPS points or cross-gap lines are created.
List<List<TripRoutePoint>> displayRouteSegments(
    List<TripRoutePoint> route, {
    int simplifyAbove = 750,
    double toleranceMeters = 2.5,
  }) {
  final separated = <int, List<TripRoutePoint>>{};
  for (final point in route) {
    separated.putIfAbsent(point.segment, () => <TripRoutePoint>[])
        .add(point);
  }
  final result = <List<TripRoutePoint>>[];
  for (final segment in separated.values) {
    if (segment.length < 2) continue;
    if (segment.length <= simplifyAbove) {
      result.add(segment);
    } else {
      result.add(_simplifyInChunks(segment, toleranceMeters));
    }
  }
  return result;
}

/// Incremental geometry for append-only trip routes. Completed 64-fix
/// windows are simplified once; only the open tail is recalculated as new
/// positions arrive. This is a display cache, never a source of fare/GPS data.
/// Replaced or truncated inputs invalidate cached windows; same-list inputs
/// must be append-only (the established trip-route contract).
class RouteRenderGeometryCache {
  List<TripRoutePoint>? _source;
  int _processed = 0;
  TripRoutePoint? _lastProcessed;
  int? _threshold;
  double? _tolerance;
  final Map<int, _RouteSegmentCache> _segments = {};
  List<List<TripRoutePoint>>? _output;

  /// Number of finalized 64-fix windows calculated since the last reset.
  /// Intended for regression tests / profiling, not monetary accounting.
  int get finalizedWindowCalculations => _segments.values.fold<int>(
      0, (sum, segment) => sum + segment.completedCalculations);

  void reset() {
    _source = null;
    _processed = 0;
    _lastProcessed = null;
    _threshold = null;
    _tolerance = null;
    _segments.clear();
    _output = null;
  }

  List<List<TripRoutePoint>> render(
    List<TripRoutePoint> route, {
    int simplifyAbove = 750,
    double toleranceMeters = 2.5,
  }) {
    if (simplifyAbove < 1 || toleranceMeters < 0) {
      throw ArgumentError('Invalid visual route simplification settings');
    }
    final replaced = !identical(route, _source) ||
        route.length < _processed ||
        (_processed > 0 &&
          !identical(route[_processed - 1], _lastProcessed)) ||
        _threshold != simplifyAbove || _tolerance != toleranceMeters;
    if (replaced) reset();
    if (_output != null && _processed == route.length) return _output!;

    for (var i = _processed; i < route.length; i++) {
      final point = route[i];
      _segments.putIfAbsent(point.segment, _RouteSegmentCache.new)
          .points.add(point);
    }
    _source = route;
    _processed = route.length;
    _lastProcessed = route.isEmpty ? null : route.last;
    _threshold = simplifyAbove;
    _tolerance = toleranceMeters;
    final result = <List<TripRoutePoint>>[];
    for (final segment in _segments.values) {
      if (segment.points.length < 2) continue;
      result.add(segment.points.length <= simplifyAbove
          ? List<TripRoutePoint>.unmodifiable(segment.points)
          : segment.simplified(toleranceMeters));
    }
    return _output = List<List<TripRoutePoint>>.unmodifiable(result);
  }
}

class _RouteSegmentCache {
  final List<TripRoutePoint> points = [];
  final List<List<TripRoutePoint>> _completedWindows = [];
  static const int _window = 64;
  int completedCalculations = 0;

  List<TripRoutePoint> simplified(double toleranceMeters) {
    final last = points.length - 1;
    // Every complete window of 64 intervals is immutable in append-only
    // history, so its geometry never needs another expensive RDP walk.
    while ((_completedWindows.length + 1) * _window <= last) {
      final start = _completedWindows.length * _window;
      _completedWindows.add(_simplifyWindow(
          points, start, start + _window, toleranceMeters));
      completedCalculations++;
    }

    final result = <TripRoutePoint>[];
    for (final chunk in _completedWindows) {
      result.addAll(result.isEmpty ? chunk : chunk.skip(1));
    }
    final start = _completedWindows.length * _window;
    if (start < last) {
      final tail = _simplifyWindow(points, start, last, toleranceMeters);
      result.addAll(result.isEmpty ? tail : tail.skip(1));
    }
    return List<TripRoutePoint>.unmodifiable(result);
  }
}

/// Process independent 64-point windows rather than globally applying RDP:
/// avoids unbounded quadratic work on a multi-hour GPS track, preserving
/// exact chunk boundaries and all points farther than the tolerance.
List<TripRoutePoint> _simplifyInChunks(
    List<TripRoutePoint> points, double toleranceMeters) {
  final result = <TripRoutePoint>[];
  const window = 64;
  for (var start = 0; start < points.length - 1; start += window) {
    final end = math.min(start + window, points.length - 1);
    final chunk = _simplifyWindow(points, start, end, toleranceMeters);
    // Do not insert a chunk boundary twice.
    result.addAll(result.isEmpty ? chunk : chunk.skip(1));
  }
  return result;
}

List<TripRoutePoint> _simplifyWindow(
    List<TripRoutePoint> points, int start, int end, double toleranceMeters) {
  final keep = List<bool>.filled(end - start + 1, false);
  keep[0] = true;
  keep[end - start] = true;
  final stack = <(int, int)>[(start, end)];
  while (stack.isNotEmpty) {
    final (from, to) = stack.removeLast();
    if (to - from <= 1) continue;
    var largest = 0.0;
    var index = -1;
    for (var i = from + 1; i < to; i++) {
      final deviation =
          _perpendicularMeters(points[i], points[from], points[to]);
      if (deviation > largest) {
        largest = deviation;
        index = i;
      }
    }
    if (largest > toleranceMeters && index >= 0) {
      keep[index - start] = true;
      stack.add((from, index));
      stack.add((index, to));
    }
  }
  final rendered = <TripRoutePoint>[];
  for (var i = start; i <= end; i++) {
    if (keep[i - start]) rendered.add(points[i]);
  }
  return rendered;
}

/// Equirectangular local projection is sufficient for a short 64-fix window.
/// Input and output coordinates are ONLY used to decide which original
/// positions to paint; distance billing always uses raw accepted GPS fixes.
double _perpendicularMeters(
    TripRoutePoint p, TripRoutePoint a, TripRoutePoint b) {
  const metersPerDegree = 111320.0;
  final cosLat = math.cos(
      ((a.latitude + b.latitude) * 0.5) * math.pi / 180).abs();
  final bx = (b.longitude - a.longitude) * cosLat * metersPerDegree;
  final by = (b.latitude - a.latitude) * metersPerDegree;
  final px = (p.longitude - a.longitude) * cosLat * metersPerDegree;
  final py = (p.latitude - a.latitude) * metersPerDegree;
  final squared = bx * bx + by * by;
  if (squared < 0.000001) return math.sqrt(px * px + py * py);
  final projection = ((px * bx + py * by) / squared).clamp(0.0, 1.0);
  final dx = px - projection * bx, dy = py - projection * by;
  return math.sqrt(dx * dx + dy * dy);
}
