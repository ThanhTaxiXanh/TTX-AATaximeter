import 'dart:math' as math;

/// Avoid querying every loaded vector-tile street feature at a standstill.
/// MapLibre queries are visual metadata, not GPS validation or fare inputs.
/// Force is used after a style reload or when the street-label UI is enabled.
class RoadQueryGate {
  RoadQueryGate({
    this.minimumInterval = const Duration(seconds: 6),
    this.stationaryRefresh = const Duration(seconds: 45),
    this.unresolvedRefresh = const Duration(seconds: 15),
    this.minMoveMeters = 18,
  });

  final Duration minimumInterval, stationaryRefresh, unresolvedRefresh;
  final double minMoveMeters;
  DateTime? _queriedAt;
  double? _latitude, _longitude;
  bool _hasName = false;

  bool shouldQuery({
    required DateTime now,
    required double latitude,
    required double longitude,
    bool force = false,
  }) {
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude.abs() > 90 || longitude.abs() > 180) return false;
    final prev = _queriedAt;
    if (!force && prev != null) {
      final age = now.difference(prev);
      if (!age.isNegative && age < minimumInterval) return false;
      final moved = _latitude == null || _longitude == null ||
          _distanceMeters(_latitude!, _longitude!,
              latitude, longitude) >= minMoveMeters;
      if (!moved && !age.isNegative &&
          age < (_hasName ? stationaryRefresh : unresolvedRefresh)) {
        return false;
      }
    }
    _queriedAt = now;
    _latitude = latitude;
    _longitude = longitude;
    return true;
  }

  void reportName(String? name) {
    _hasName = name != null && name.trim().isNotEmpty;
  }

  void reset() {
    _queriedAt = null;
    _latitude = null;
    _longitude = null;
    _hasName = false;
  }

  static double _distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const radiusMeters = 6371000.0;
    final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) *
        math.sin(dl / 2) * math.sin(dl / 2);
    return radiusMeters * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }
}
