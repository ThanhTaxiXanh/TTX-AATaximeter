import 'dart:math' as math;

/// Restricts expensive native MapLibre camera animations. This is only a
/// presentation filter: GPS fixes and the fare engine are never discarded.
class FollowCameraGate {
  FollowCameraGate({
    this.minimumInterval = const Duration(milliseconds: 400),
    this.minimumDistanceMeters = 2.5,
    this.minimumBearingDegrees = 3.0,
  });

  final Duration minimumInterval;
  final double minimumDistanceMeters;
  final double minimumBearingDegrees;

  DateTime? _lastTime;
  double? _lastLat, _lastLon, _lastBearing, _lastZoom;

  void reset() {
    _lastTime = null;
    _lastLat = null;
    _lastLon = null;
    _lastBearing = null;
    _lastZoom = null;
  }

  bool shouldUpdate({
    required DateTime at,
    required double latitude,
    required double longitude,
    required double bearing,
    required double zoom,
    bool force = false,
  }) {
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude.abs() > 90 || longitude.abs() > 180 ||
        !bearing.isFinite || !zoom.isFinite) return false;
    final last = _lastTime;
    if (!force && last != null) {
      if (at.isBefore(last) || at.difference(last) < minimumInterval) {
        return false;
      }
      final moved = _distanceMeters(
        _lastLat!, _lastLon!, latitude, longitude);
      final angle = ((bearing - _lastBearing!).abs() % 360);
      final headingChange = math.min(angle, 360 - angle);
      if (moved < minimumDistanceMeters &&
          headingChange < minimumBearingDegrees &&
          (zoom - _lastZoom!).abs() < 0.01) return false;
    }
    _lastTime = at;
    _lastLat = latitude;
    _lastLon = longitude;
    _lastBearing = bearing;
    _lastZoom = zoom;
    return true;
  }

  static double _distanceMeters(
      double aLat, double aLon, double bLat, double bLon) {
    const radius = 6371000.0;
    final lat1 = aLat * math.pi / 180;
    final lat2 = bLat * math.pi / 180;
    final dLat = (bLat - aLat) * math.pi / 180;
    final dLon = (bLon - aLon) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.pow(math.sin(dLon / 2), 2);
    return radius * 2 * math.atan2(
        math.sqrt(h), math.sqrt(math.max(0, 1 - h)));
  }
}
