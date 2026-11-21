import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign_catalog.dart';

void main() {
  test('V1 uses exactly the owner-confirmed type mapping', () {
    const expected = <int, String>{
      1: 'Biển báo tốc độ',
      2: 'Vào khu dân cư',
      3: 'Hết khu dân cư',
      4: 'Camera giao thông',
      5: 'Cấm vượt',
      6: 'Hết cấm vượt',
      10: 'Camera AI',
      32: 'Đèn đỏ',
      36: 'Cấm ô tô rẽ phải',
      38: 'Cấm rẽ trái và quay đầu',
      40: 'Cấm rẽ trái',
      50: 'Cấm dừng/đỗ',
      51: 'Cấm dừng/đỗ',
    };
    expect(TrafficSignCatalog.knownCodes.keys.toSet(),
        expected.keys.toSet());
    for (final row in expected.entries) {
      expect(TrafficSignCatalog.description(row.key), row.value);
      expect(TrafficSignCatalog.filterTitle(row.key),
          '${row.key} · ${row.value}');
    }
  });

  test('unknown sign codes stay unknown, not assigned inferred meanings', () {
    expect(TrafficSignCatalog.description(43),
        'Chưa xác định (mã 43)');
    expect(TrafficSignCatalog.markerLabel(43, 90), '?');
    expect(TrafficSignCatalog.description(52),
        contains('Chưa xác định'));
  });

  test('positive raw value belongs to posted speed only for code 1', () {
    expect(TrafficSignCatalog.postedSpeedNumber(1, 50), 50);
    expect(TrafficSignCatalog.postedSpeedNumber(1, 80), 80);
    expect(TrafficSignCatalog.postedSpeedNumber(1, 0), null);
    expect(TrafficSignCatalog.markerLabel(1, 50,
        legacyInferredSpeed: 50), '50');
    // Actual SQLite contains a few >0 values in non-speed categories.
    // They must never be rendered as road speed limits.
    expect(TrafficSignCatalog.postedSpeedNumber(4, 178), null);
    expect(TrafficSignCatalog.postedSpeedNumber(50, 60), null);
    expect(TrafficSignCatalog.markerLabel(4, 178), 'CAM');
    expect(TrafficSignCatalog.markerLabel(10, 0), 'AI');
    expect(TrafficSignCatalog.markerLabel(50, 60), 'D/Đ');
    expect(TrafficSignCatalog.markerLabel(51, 0), 'D/Đ');
    expect(TrafficSignCatalog.markerLabel(null, null,
        legacyInferredSpeed: 70), '~70');
  });

  test('V1 is provisional and keeps raw value as data, not a legal rule', () {
    expect(TrafficSignCatalog.description(38),
      'Cấm rẽ trái và quay đầu');
    expect(TrafficSignCatalog.description(40), 'Cấm rẽ trái');
    expect(TrafficSignCatalog.postedSpeedNumber(32, 10), null);
  });
}
