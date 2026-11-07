/// Visual-only change detector for GPS map frames. The authoritative meter,
/// route storage and background GPS subscriptions never depend on this gate.
class MapPresentationGate {
  double? _latitude, _longitude, _heading;
  int? _speed;
  int? _routeCount;
  bool _initialized = false;
  int observed = 0;
  int published = 0;

  bool shouldPublish({
    required double? latitude,
    required double? longitude,
    required double headingDegrees,
    required double speedKmh,
    required int routePointCount,
    bool force = false,
  }) {
    observed++;
    final roundedSpeed = speedKmh.isFinite
        ? speedKmh.clamp(0.0, 300.0).round() : 0;
    final bearing = headingDegrees.isFinite
        ? ((headingDegrees % 360) + 360) % 360 : 0.0;
    final headingDelta = _heading == null ? 360.0
        : (((bearing - _heading! + 540) % 360) - 180).abs();
    // A microscopic float change is not a map movement. Stationary GPS
    // drift is already filtered upstream by _updateMapGpsPosition.
    final moved = _latitude == null || _longitude == null ||
        latitude == null || longitude == null
        ? latitude != _latitude || longitude != _longitude
        : (latitude - _latitude!).abs() > 0.000004 ||
          (longitude - _longitude!).abs() > 0.000004;
    final changed = force || !_initialized || moved ||
        headingDelta >= 2.5 || _speed != roundedSpeed ||
        _routeCount != routePointCount;
    if (!changed) return false;
    _initialized = true;
    _latitude = latitude;
    _longitude = longitude;
    _heading = bearing;
    _speed = roundedSpeed;
    _routeCount = routePointCount;
    published++;
    return true;
  }

  void reset() {
    _initialized = false;
  }
}
