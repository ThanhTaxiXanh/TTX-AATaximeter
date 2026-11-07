import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/vietnam_map_sovereignty.dart';

void main() {
  test('mandatory Vietnamese island-group and sea names stay exact', () {
    expect(VietnamMapSovereignty.hoangSa, 'Hoàng Sa (Việt Nam)');
    expect(VietnamMapSovereignty.truongSa, 'Trường Sa (Việt Nam)');
    expect(VietnamMapSovereignty.bienDong, 'Biển Đông');
    expect(VietnamMapSovereignty.labels.map((p) => p.name),
      [
        'Hoàng Sa (Việt Nam)',
        'Trường Sa (Việt Nam)',
        'Biển Đông',
      ]);
  });

  test('Dart-owned geographic name output normalizes competing aliases', () {
    final cases = <String, String>{
      'Paracel Islands': 'Hoàng Sa (Việt Nam)',
      'Paracels': 'Hoàng Sa (Việt Nam)',
      'Xisha Islands': 'Hoàng Sa (Việt Nam)',
      '西沙群岛': 'Hoàng Sa (Việt Nam)',
      'Spratly Islands': 'Trường Sa (Việt Nam)',
      'Spratlys': 'Trường Sa (Việt Nam)',
      'Nansha Qundao': 'Trường Sa (Việt Nam)',
      '南沙群島': 'Trường Sa (Việt Nam)',
      'South China Sea': 'Biển Đông',
      '南中国海': 'Biển Đông',
    };
    for (final item in cases.entries) {
      expect(VietnamMapSovereignty.approvedLabel(item.key), item.value,
        reason: 'Unreviewed alias leaked to a map/search label');
    }
    expect(VietnamMapSovereignty.approvedLabel(
      'Vùng South China Sea'), 'Vùng Biển Đông');
    expect(VietnamMapSovereignty.approvedLabel('Đường Trần Phú'),
        'Đường Trần Phú');
  });

  test('prohibited disputed-boundary captions are suppressed, not relabeled',
      () {
    for (final claim in [
      'nine-dash line', '9 dash line',
      'ten-dash line', 'đường lưỡi bò', 'đường chín đoạn',
      '九段线',
    ]) {
      expect(VietnamMapSovereignty.approvedLabel(claim), isNull,
          reason: '$claim cannot be rendered by app-owned labels');
    }
    expect(VietnamMapSovereignty.approvedLabel(null), isNull);
    expect(VietnamMapSovereignty.approvedLabel('  '), isNull);
  });

  test('GeoJSON adds only text anchors, no fabricated territorial boundaries',
      () {
    final geo = VietnamMapSovereignty.geoJsonLabels();
    expect(geo['type'], 'FeatureCollection');
    final features = (geo['features'] as List).cast<Map<String, dynamic>>();
    expect(features.length, 3);
    for (final feature in features) {
      final properties =
          (feature['properties'] as Map).cast<String, dynamic>();
      final geometry =
          (feature['geometry'] as Map).cast<String, dynamic>();
      expect(properties['anchor_only'], isTrue);
      expect(properties['policy'], 'TTX-VN-MAP-01');
      expect(properties['name'], VietnamMapSovereignty.labels
          .map((label) => label.name).contains(properties['name']) ? properties['name'] : null);
      expect(geometry['type'], 'Point');
      final coordinates = (geometry['coordinates'] as List).cast<double>();
      expect(coordinates.length, 2);
      expect(coordinates[0], inInclusiveRange(-180.0, 180.0));
      expect(coordinates[1], inInclusiveRange(-90.0, 90.0));
    }
    expect(geo.toString(), isNot(contains('Polygon')));
    expect(geo.toString(), isNot(contains('LineString')));
  });

  test('reviewed map URL selection remains centralized', () {
    expect(VietnamMapSovereignty.openFreeMapDark,
        'https://tiles.openfreemap.org/styles/dark');
    expect(VietnamMapSovereignty.openFreeMapLiberty,
        'https://tiles.openfreemap.org/styles/liberty');
    expect(VietnamMapSovereignty.osmRasterTiles,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  });
}
