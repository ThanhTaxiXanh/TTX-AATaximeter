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

/// Process independent 64-point windows rather than globally applying RDP:
/// avoids unbounded quadratic work on a multi-hour GPS track, preserving
/// exact chunk boundaries and all points farther than the tolerance.
List<TripRoutePoint> _simplifyInChunks(
    List<TripRoutePoint> points, double toleranceMeters) {
  final result = <TripRoutePoint>[];
  const window = 64;
  for (var start = 0; start < points.length - 1; start += window) {
    final end = math.min(start + window, points.length - 1);
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
    // Do not insert a chunk boundary twice.
    for (var i = start == 0 ? start : start + 1; i <= end; i++) {
      if (keep[i - start]) result.add(points[i]);
    }
  }
  return result;
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
