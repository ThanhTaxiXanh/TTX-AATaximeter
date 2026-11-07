import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/nearest_road_name.dart';

Map<String, Object> road(String name, List<List<double>> coords,
    {String field = 'name'}) => {
  'type': 'Feature',
  'properties': {field: name},
  'geometry': {'type': 'LineString', 'coordinates': coords},
};

void main() {
  test('nearest road wins over a distant road even if features are reversed',
      () {
    final roads = [
      road('Đường xa', [[105.840, 21.030], [105.840, 21.031]]),
      road('Trần Nguyên Hãn',
        [[105.8340, 21.0278], [105.8340, 21.0283]]),
    ];
    expect(nearestRoadName(roads,
      latitude: 21.028, longitude: 105.83402),
      'Trần Nguyên Hãn');
  });

  test('Vietnamese name preferred, fallback to ref if street is unnamed', () {
    final candidates = [
      {
        'properties': {'name': 'Street', 'name:vi': 'Đường Yết Kiêu'},
        'geometry': {'type': 'LineString',
          'coordinates': [[105.834, 21.028], [105.835, 21.028]]},
      },
    ];
    expect(nearestRoadName(candidates,
      latitude: 21.02801, longitude: 105.8345),
      'Đường Yết Kiêu');
    expect(nearestRoadName([
      road('DT295B', [[105.834, 21.028], [105.835, 21.028]],
        field: 'ref'),
    ], latitude: 21.028, longitude: 105.8345), 'DT295B');
  });

  test('rejects distant roads instead of inventing a street name', () {
    final nearby = road('Not nearby',
      [[105.9, 21.09], [105.91, 21.09]]);
    expect(nearestRoadName([nearby],
      latitude: 21.028, longitude: 105.834), isNull);
    expect(nearestRoadName([nearby],
      latitude: 91, longitude: 105.834), isNull);
  });

  test('supports MultiLineString and ignores broken geometry', () {
    final parts = [
      {
        'properties': {'name': 'Quốc lộ 1A'},
        'geometry': {
          'type': 'MultiLineString',
          'coordinates': [
            [[105.82, 21.02], [105.83, 21.02]],
            [[105.834, 21.028], [105.835, 21.028]],
          ],
        },
      },
      {
        'properties': {'name': 'Invalid'},
        'geometry': {'type': 'Point', 'coordinates': [105.834, 21.028]},
      },
    ];
    expect(nearestRoadName(parts,
      latitude: 21.028, longitude: 105.8341), 'Quốc lộ 1A');
  });

  test('direction only mildly favors parallel same-distance roads', () {
    final roads = [
      road('Song song',
        [[105.834, 21.028], [105.834, 21.0285]]),
      road('Cắt ngang',
        [[105.8338, 21.028], [105.8342, 21.028]]),
    ];
    final label = nearestRoadName(roads,
      latitude: 21.028, longitude: 105.834,
      bearingDegrees: 0);
    expect(label, 'Song song');
  });
}
