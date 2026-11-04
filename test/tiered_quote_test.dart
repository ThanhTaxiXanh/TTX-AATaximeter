import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/quote_calculator.dart';

void main() {
  test('quote uses progressive tiers when rate is not overridden', () {
    final t = TariffConfig.demo().copyWith(
      baseFare: 10000, baseDistanceKm: 1, perKmRate: 16000,
      fareTiers: const [
        FareTier(upToKm: 3, ratePerKm: 16000),
        FareTier(upToKm: 10, ratePerKm: 14000),
        FareTier(upToKm: null, ratePerKm: 12000),
      ],
    );
    const calc = QuoteCalculator();
    expect(calc.estimate(
      tariff: t, distanceKm: 11, perKmRate: t.perKmRate),
      10000 + 2 * 16000 + 7 * 14000 + 12000);
  });

  test('single observed 15km fare stays compatible after tiered editor', () {
    final tariff = TariffConfig.demo();
    final tiers = tariff.copyWith(fareTiers: tariff.effectiveFareTiers);
    expect(tiers.distanceChargeForKm(15),
        tariff.distanceChargeForKm(15));
    final meter = TaximeterEngine(tariff: tiers);
    meter.start(at: DateTime(2026, 11, 4));
    meter.distanceMeters = 15000;
    expect(meter.totalFare, 222000);
  });
}
