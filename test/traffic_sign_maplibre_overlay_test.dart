import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';
import 'package:ttx_aataximeter/src/traffic_signs/presentation/traffic_sign_maplibre_overlay.dart';

void main() {
  test('empty viewport result creates an empty GeoJSON FeatureCollection', () {
    expect(trafficSignFeatureCollection(SignViewportResult.empty), {
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[],
    });
  });

  test('single sign preserves WGS84 longitude-latitude order and raw id', () {
    final geoJson = trafficSignFeatureCollection(SignViewportResult(
      total: 1,
      items: const [
        SignMapItem(
          signId: 0,
          longitude: 106.1234,
          latitude: 21.5678,
          count: 1,
          speedKmhInferred: 60,
        ),
      ],
    ));
    final feature = (geoJson['features'] as List).single as Map;
    expect(feature['id'], 0);
    expect(feature['geometry']['coordinates'], [106.1234, 21.5678]);
    expect(feature['properties']['sign_id'], 0);
    expect(feature['properties']['speed_kmh_inferred'], 60);
  });

  test('cluster aggregate retains count and does not invent speed values', () {
    final geoJson = trafficSignFeatureCollection(SignViewportResult(
      total: 4,
      items: const [
        SignMapItem(
          signId: 10,
          longitude: 106.0,
          latitude: 21.0,
          count: 4,
        ),
      ],
    ));
    final properties =
        ((geoJson['features'] as List).single as Map)['properties'] as Map;
    expect(properties['count'], 4);
    expect(properties.containsKey('speed_kmh_inferred'), isFalse);
  });
}
