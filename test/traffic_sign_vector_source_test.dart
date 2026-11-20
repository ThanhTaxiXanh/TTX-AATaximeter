import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';
import 'package:ttx_aataximeter/src/traffic_signs/presentation/traffic_sign_vector_source.dart';

void main() {
  test('MapLibre features keep longitude/latitude order and exact IDs', () {
    const records = [
      SignMapItem(signId: 0, longitude: 105.85, latitude: 21.03,
        count: 1),
      SignMapItem(signId: 37, longitude: 106.65, latitude: 10.76,
        count: 1, speedKmhInferred: 60),
      SignMapItem(signId: 91, longitude: 108.7, latitude: 16.05,
        count: 123),
    ];
    final geojson = TrafficSignVectorSource.features(records);
    expect(geojson['type'], 'FeatureCollection');
    final features = (geojson['features'] as List).cast<Map<String, dynamic>>();
    expect(features.length, 3);
    expect(features.map((f) => f['id']),
      ['sign_0', 'sign_37', 'cluster_91']);

    final coordinates = (features[0]['geometry'] as Map)['coordinates'];
    expect(coordinates, [105.85, 21.03]);
    expect((features[1]['properties'] as Map)['display'], '~60');
    expect((features[2]['properties'] as Map)['count'], 123);
    expect((features[2]['properties'] as Map)['display'], '123');
    for (final feature in features) {
      expect((feature['geometry'] as Map)['type'], 'Point');
      expect((feature['properties'] as Map)['verification_status'],
        'unverified');
    }
    expect(geojson.toString(), isNot(contains('Polygon')));
  });

  test('native tap only resolves a current visible ID', () {
    const record = SignMapItem(signId: 0, longitude: 105.85,
      latitude: 21.03, count: 1);
    const cluster = SignMapItem(signId: 17, longitude: 107,
      latitude: 21, count: 500);
    final visible = {
      TrafficSignVectorSource.featureId(record): record,
      TrafficSignVectorSource.featureId(cluster): cluster,
    };
    expect(TrafficSignVectorSource.tapped('sign_0', visible), same(record));
    expect(TrafficSignVectorSource.tapped('cluster_17', visible),
      same(cluster));
    expect(TrafficSignVectorSource.tapped('sign_999', visible), isNull);
    expect(TrafficSignVectorSource.tapped('ttx-route', visible), isNull);
  });

  test('display never presents inferred speed as verified road limit', () {
    const s = SignMapItem(signId: 1, longitude: 105.8,
      latitude: 21, count: 1, speedKmhInferred: 80);
    const unknown = SignMapItem(signId: 2, longitude: 105.8,
      latitude: 21, count: 1);
    const aggregate = SignMapItem(signId: 3, longitude: 105.8,
      latitude: 21, count: 151228);
    expect(TrafficSignVectorSource.label(s), '~80');
    expect(TrafficSignVectorSource.label(unknown), '?');
    expect(TrafficSignVectorSource.label(aggregate), '151k+');
  });
}
