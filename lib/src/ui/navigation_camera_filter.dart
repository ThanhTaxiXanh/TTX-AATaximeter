import 'dart:math' as math;

/// Camera-only visual smoothing. Metering, GPS recording and the navigation
/// arrow always use the ORIGINAL validated location fix instead.
class NavigationCameraPose {
  const NavigationCameraPose({
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
  });

  final double latitude;
  final double longitude;
  final double headingDegrees;
}

class NavigationCameraFilter {
  NavigationCameraPose? _last;
  DateTime? _lastAt;

  void reset() {
    _last = null;
    _lastAt = null;
  }

  NavigationCameraPose update({
    required DateTime at,
    required double latitude,
    required double longitude,
    required double headingDegrees,
    required double speedKmh,
  }) {
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude.abs() > 90 || longitude.abs() > 180 ||
        !headingDegrees.isFinite) {
      throw const FormatException('Invalid camera GPS fix');
    }

    final bearing = normalizeDegrees(headingDegrees);
    final previous = _last;
    final previousAt = _lastAt;
    if (previous == null || previousAt == null ||
        !at.isAfter(previousAt)) {
      final first = NavigationCameraPose(
        latitude: latitude, longitude: longitude,
        headingDegrees: bearing);
      if (previous == null) {
        _last = first;
        _lastAt = at;
      }
      return _last!;
    }

    final seconds = at.difference(previousAt).inMilliseconds / 1000.0;
    final meters = distanceMeters(previous.latitude, previous.longitude,
        latitude, longitude);
    // Reconnect after a long GPS gap or a large jump without visually
    // dragging the camera across the city. This is NOT distance billing.
    if (seconds > 8 || meters > 85) {
      final snapped = NavigationCameraPose(
        latitude: latitude, longitude: longitude,
        headingDegrees: bearing);
      _last = snapped;
      _lastAt = at;
      return snapped;
    }

    final speed = speedKmh.isFinite
        ? speedKmh.clamp(0.0, 200.0).toDouble() : 0.0;
    final positionTau = speed >= 25 ? 0.40 :
        speed >= 10 ? 0.65 : 1.20;
    final alpha = (1 - math.exp(-seconds / positionTau))
        .clamp(0.0, 1.0).toDouble();
    // Do not allow 1-3m stationary GPS drift to shake the 3D scene.
    final stationary = speed < 3 && meters < 4;
    final lat = stationary ? previous.latitude :
        previous.latitude + (latitude - previous.latitude) * alpha;
    final lon = stationary ? previous.longitude :
        previous.longitude + (longitude - previous.longitude) * alpha;

    // GPS course is inherently unstable near zero speed. Hold the last
    // stable display heading until the car is moving again.
    final delta = shortestHeadingDelta(previous.headingDegrees, bearing);
    final headingTau = speed >= 15 ? 0.75 : 1.15;
    var headingAlpha = (1 - math.exp(-seconds / headingTau))
        .clamp(0.0, 1.0).toDouble();
    if (speed >= 8 && delta.abs() > 65) {
      // Allow an actual sharp turn without excessive lag.
      headingAlpha = math.max(headingAlpha, 0.76);
    }
    final heading = speed < 5 || delta.abs() < 2.0
        ? previous.headingDegrees
        : normalizeDegrees(previous.headingDegrees + delta * headingAlpha);

    final filtered = NavigationCameraPose(
      latitude: lat, longitude: lon, headingDegrees: heading);
    _last = filtered;
    _lastAt = at;
    return filtered;
  }

  static double normalizeDegrees(double degrees) =>
      ((degrees % 360) + 360) % 360;

  static double shortestHeadingDelta(double from, double to) =>
      ((normalizeDegrees(to) - normalizeDegrees(from) + 540) % 360) - 180;

  static double distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final a = lat1 * math.pi / 180;
    final b = lat2 * math.pi / 180;
    final latDelta = (lat2 - lat1) * math.pi / 180;
    final lonDelta = (lon2 - lon1) * math.pi / 180;
    final haversine = math.pow(math.sin(latDelta / 2), 2) +
        math.cos(a) * math.cos(b) *
        math.pow(math.sin(lonDelta / 2), 2);
    return 2 * earthRadius * math.atan2(
        math.sqrt(haversine), math.sqrt(math.max(0, 1 - haversine)));
  }
}
