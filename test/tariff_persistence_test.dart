import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/tariff_codec.dart';

void main() {
  test('tariff persistence preserves editable GPS/tariff parameters', () {
    final t = TariffConfig.demo().copyWith(
      baseFare: 19000, baseDistanceKm: 0.7,
      perKmRate: 16500, gpsMaxAccuracyMeters: 25,
      gpsCalibrationMultiplier: 1.02, roundToThousands: false,
    );
    final decoded = TariffCodec.decode(TariffCodec.encode(t));
    expect(decoded.baseFare, 19000);
    expect(decoded.baseDistanceKm, 0.7);
    expect(decoded.perKmRate, 16500);
    expect(decoded.gpsMaxAccuracyMeters, 25);
    expect(decoded.gpsCalibrationMultiplier, 1.02);
    expect(decoded.roundToThousands, false);
  });

  test('reject invalid saved tariff to protect calculation', () {
    expect(() => TariffCodec.decode(
      '{"baseDistanceKm":20,"longDistanceThresholdKm":1}'),
      throwsArgumentError);
  });
}
