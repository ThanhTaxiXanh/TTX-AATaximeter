import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/drive_map_3d.dart';

void main() {
  test('3D arrow uses the exact GPS longitude/latitude, not camera lead', () {
    final geo = gpsArrowGeoJson(21.0278, 105.8342, 87);
    final features = geo['features'] as List;
    expect(features.length, 1);
    final point = features.first as Map;
    expect((point['geometry'] as Map)['coordinates'], [105.8342, 21.0278]);
    expect((point['properties'] as Map)['heading'], 87.0);
  });

  test('3D arrow normalizes heading and does not invent GPS point', () {
    expect((gpsArrowGeoJson(21, 106, -45)['features'] as List)
        .first['properties']['heading'], 315.0);
    expect(gpsArrowGeoJson(null, null, 0)['features'], isEmpty);
    expect(gpsArrowGeoJson(95, 106, 0)['features'], isEmpty);
    expect(gpsArrowGeoJson(21, 200, 0)['features'], isEmpty);
  });
}
