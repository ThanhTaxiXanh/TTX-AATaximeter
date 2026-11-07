/// A trustworthy GPS sample accepted by the fare engine.
/// A segment boundary intentionally avoids drawing a false line across GPS gaps.
class TripRoutePoint {
  const TripRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
    required this.speedKmh,
    this.segment = 0,
  });

  final double latitude, longitude, accuracyMeters, speedKmh;
  final DateTime recordedAt;
  final int segment;

  Map<String, dynamic> toJson() => {
    'lat': latitude, 'lon': longitude,
    'at': recordedAt.toIso8601String(),
    'accuracy': accuracyMeters, 'speed': speedKmh, 'segment': segment,
  };

  factory TripRoutePoint.fromJson(Map<String, dynamic> data) {
    double number(String key) {
      final v = data[key];
      if (v is! num || !v.toDouble().isFinite) {
        throw FormatException('Invalid route $key');
      }
      return v.toDouble();
    }
    final lat = number('lat'), lon = number('lon');
    final accuracy = number('accuracy'), speed = number('speed');
    final time = DateTime.tryParse(data['at']?.toString() ?? '');
    final index = data['segment'];
    if (lat.abs() > 90 || lon.abs() > 180 ||
        accuracy < 0 || speed < 0 || time == null ||
        index is! int || index < 0) {
      throw const FormatException('Invalid GPS route point');
    }
    return TripRoutePoint(
      latitude: lat, longitude: lon, recordedAt: time,
      accuracyMeters: accuracy, speedKmh: speed, segment: index,
    );
  }
}
