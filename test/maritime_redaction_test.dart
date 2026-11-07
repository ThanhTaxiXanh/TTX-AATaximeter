import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/vietnam_map_sovereignty.dart';

void main() {
  test('unverified maritime areas are visibly masked, never left to tiles',
      () {
    final zones = VietnamMapSovereignty.maritimeRedactionZones;
    expect(zones.length, 3);
    expect(zones.map((z) => z.name), ['Hoàng Sa', 'Trường Sa', 'Biển Đông']);
    for (final label in VietnamMapSovereignty.labels) {
      expect(zones.any((z) =>
          label.longitude >= z.west &&
          label.longitude <= z.east &&
          label.latitude >= z.south &&
          label.latitude <= z.north),
        isTrue,
        reason: '${label.name} must be inside a visual redaction zone');
    }
  });

  test('no temporary raster/vector masking zone covers inland Hanoi or HCMC',
      () {
    for (final point in <(double, double)>[
      (21.0285, 105.8542), // Hà Nội
      (10.8231, 106.6297), // TPHCM
      (16.0544, 108.2022), // Đà Nẵng
    ]) {
      for (final z in VietnamMapSovereignty.maritimeRedactionZones) {
        expect(point.$2 >= z.west && point.$2 <= z.east &&
          point.$1 >= z.south && point.$1 <= z.north, isFalse,
          reason: 'Mainland taxi map must retain navigable road basemap');
      }
    }
  });

  test('vector redaction produces closed, opaque-covering polygons only',
      () {
    final json = VietnamMapSovereignty.geoJsonMaritimeRedactions();
    expect(json['type'], 'FeatureCollection');
    final features =
        (json['features'] as List).cast<Map<String, dynamic>>();
    expect(features.length, 3);
    for (final feature in features) {
      final props =
          (feature['properties'] as Map).cast<String, dynamic>();
      final geometry =
          (feature['geometry'] as Map).cast<String, dynamic>();
      expect(props['redaction_only'], isTrue);
      expect(props['not_a_boundary'], isTrue);
      expect(props['policy'], 'TTX-VN-MAP-01');
      expect(geometry['type'], 'Polygon');
      final rings = (geometry['coordinates'] as List);
      expect(rings.length, 1);
      final exterior = (rings.single as List);
      expect(exterior.length, 5);
      expect(exterior.first, exterior.last);
      for (final coordinate in exterior) {
        final lon = (coordinate as List)[0] as double;
        final lat = coordinate[1] as double;
        expect(lon, inInclusiveRange(-180.0, 180.0));
        expect(lat, inInclusiveRange(-90.0, 90.0));
      }
    }
  });
}
