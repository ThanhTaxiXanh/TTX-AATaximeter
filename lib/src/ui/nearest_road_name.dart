import 'dart:math' as math;

/// Choose nearest named road from already-loaded OpenMapTiles
/// transportation_name vector features. No reverse-geocoding requests.
String? nearestRoadName(
  Iterable<dynamic> features, {
  required double latitude,
  required double longitude,
  double? bearingDegrees,
  double maxDistanceMeters = 42,
}) {
  if (!latitude.isFinite || !longitude.isFinite ||
      latitude.abs() > 90 || longitude.abs() > 180) return null;
  String? best;
  var bestScore = double.infinity;
  for (final item in features) {
    if (item is! Map || item['properties'] is! Map ||
        item['geometry'] is! Map) continue;
    final props = item['properties'] as Map;
    String? value;
    for (final key in ['name:vi', 'name', 'name:nonlatin',
      'name:latin', 'name_en', 'ref']) {
      final candidate = props[key];
      if (candidate is String && candidate.trim().isNotEmpty) {
        value = candidate.trim();
        break;
      }
    }
    if (value == null || value.length > 90) continue;
    final geometry = item['geometry'] as Map;
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];
    Iterable<dynamic> paths;
    if (type == 'LineString' && coordinates is List) {
      paths = [coordinates];
    } else if (type == 'MultiLineString' && coordinates is List) {
      paths = coordinates;
    } else {
      continue;
    }
    for (final path in paths) {
      if (path is! List || path.length < 2) continue;
      for (var i = 0; i < path.length - 1; i++) {
        final one = _point(path[i]);
        final two = _point(path[i + 1]);
        if (one == null || two == null) continue;
        final d = _distanceToSegment(latitude, longitude, one, two);
        if (!d.isFinite || d > maxDistanceMeters) continue;
        var penalty = 0.0;
        if (bearingDegrees != null && bearingDegrees.isFinite) {
          final north = (two.$1 - one.$1) * 111195;
          final east = (two.$2 - one.$2) *
              111195 * math.cos(latitude * math.pi / 180);
          if (north.abs() + east.abs() > 1) {
            final bearing = (math.atan2(east, north) * 180 / math.pi + 360) % 360;
            var diff = (bearingDegrees - bearing).abs() % 180;
            if (diff > 90) diff = 180 - diff;
            penalty = diff / 90 * 5;
          }
        }
        final score = d + penalty;
        if (score < bestScore) {
          bestScore = score;
          best = value;
        }
      }
    }
  }
  return best;
}

/// (latitude, longitude), reading GeoJSON coordinates in [lon, lat] order.
(double, double)? _point(dynamic value) {
  if (value is! List || value.length < 2 ||
      value[0] is! num || value[1] is! num) return null;
  final longitude = (value[0] as num).toDouble();
  final latitude = (value[1] as num).toDouble();
  if (!latitude.isFinite || !longitude.isFinite ||
      latitude.abs() > 90 || longitude.abs() > 180) return null;
  return (latitude, longitude);
}

double _distanceToSegment(
  double latitude, double longitude,
  (double, double) a, (double, double) b,
) {
  final cosLat = math.cos(latitude * math.pi / 180);
  double x(double lon) => (lon - longitude) * 111195 * cosLat;
  double y(double lat) => (lat - latitude) * 111195;
  final ax = x(a.$2), ay = y(a.$1);
  final bx = x(b.$2), by = y(b.$1);
  final dx = bx - ax, dy = by - ay;
  final length = dx * dx + dy * dy;
  final t = length < 0.001
      ? 0.0 : ((-ax * dx - ay * dy) / length).clamp(0.0, 1.0);
  return math.sqrt(
    math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2));
}
