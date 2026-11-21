import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/presentation/traffic_sign_icon_pack.dart';

void main() {
  test('eight matched owner icons decode to complete 64px PNG assets', () {
    const expected = {
      2: 'residential_area_start',
      3: 'residential_area_end',
      5: 'no_overtaking_start',
      6: 'no_overtaking_end',
      32: 'traffic_light',
      36: 'no_car_right_turn',
      38: 'no_left_turn_and_uturn',
      40: 'no_left_turn',
    };
    expect(TrafficSignIconPack.iconKeyByType, expected);
    for (final entry in expected.entries) {
      final png = TrafficSignIconPack.pngForCode(entry.key);
      expect(png, isNotNull, reason: 'missing ${entry.value}');
      final bytes = png!;
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 8), [
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      ]);
      final header = ByteData.sublistView(bytes);
      // Input PNGs have different aspect ratios. The 64px longest side
      // is retained; distorting a road sign into a square is forbidden.
      final width = header.getUint32(16);
      final height = header.getUint32(20);
      expect(width, inInclusiveRange(1, 64));
      expect(height, inInclusiveRange(1, 64));
      expect(width == 64 || height == 64, isTrue);
      expect(TrafficSignIconPack.mapLibreImageId(entry.key),
          'ttx-sign-icon-${entry.value}');
      // Cache never allocates new Uint8List on every camera frame.
      expect(identical(bytes, TrafficSignIconPack.pngForCode(entry.key)),
          isTrue);
    }
    final images = TrafficSignIconPack.mapLibreImages.toList();
    expect(images.length, expected.length);
    expect(images.map((item) => item.$1).toSet().length, expected.length);
  });

  test('unknown and ambiguous sign types do not receive misleading PNG', () {
    for (final code in [1, 4, 10, 43, 50, 51, 99]) {
      expect(TrafficSignIconPack.iconKey(code), isNull);
      expect(TrafficSignIconPack.mapLibreImageId(code), isNull);
      expect(TrafficSignIconPack.pngForCode(code), isNull);
    }
    expect(TrafficSignIconPack.pngForCode(null), isNull);
  });
}
