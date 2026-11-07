import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/tariff_codec.dart';
import 'package:ttx_aataximeter/src/domain/quote_calculator.dart';

void main() {
  final tiered = TariffConfig.demo().copyWith(
    name: 'Bậc giá thử nghiệm',
    baseFare: 10000,
    baseDistanceKm: 0.5,
    fareTiers: const [
      FareTier(upToKm: 5, ratePerKm: 14000),
      FareTier(upToKm: 30, ratePerKm: 12000),
      FareTier(upToKm: null, ratePerKm: 10000),
    ],
  );

  test('tier boundaries calculate cumulative price without retroactive rate', () {
    tiered.validate();
    expect(tiered.distanceChargeForKm(0.4), 0);
    expect(tiered.distanceChargeForKm(0.5), 0);
    expect(tiered.distanceChargeForKm(1), 7000);
    expect(tiered.distanceChargeForKm(5), 63000);
    expect(tiered.distanceChargeForKm(6), 75000);
    expect(tiered.distanceChargeForKm(30), 363000);
    expect(tiered.distanceChargeForKm(31), 373000);
  });

  test('taximeter uses tiered fare with waiting and BOT', () {
    final meter = TaximeterEngine(tariff: tiered.copyWith(
        roundToThousands: false));
    meter.start(at: DateTime(2026, 11, 4));
    meter.distanceMeters = 31000;
    meter.addToll(20000);
    expect(meter.baseFare, 10000);
    expect(meter.distanceFare, 373000);
    expect(meter.totalFare, 403000);
  });

  test('tier structure survives settings and recovery codec', () {
    final restored = TariffCodec.decode(TariffCodec.encode(tiered));
    expect(restored.fareTiers, hasLength(3));
    expect(restored.distanceChargeForKm(31), 373000);
    expect(restored.name, tiered.name);
  });

  test('quote at default rate uses tiered charge', () {
    final fare = const QuoteCalculator().estimate(
      tariff: tiered, distanceKm: 31,
      perKmRate: tiered.perKmRate);
    expect(fare, 383000);
  });

  test('invalid tier order, missing infinity tier and negative rate fail', () {
    for (final bands in <List<FareTier>>[
      [const FareTier(upToKm: 2, ratePerKm: 15000)],
      [
        const FareTier(upToKm: 5, ratePerKm: 14000),
        const FareTier(upToKm: 4, ratePerKm: 10000),
        const FareTier(upToKm: null, ratePerKm: 10000),
      ],
      [const FareTier(upToKm: null, ratePerKm: -1)],
    ]) {
      expect(() => tiered.copyWith(fareTiers: bands).validate(),
          throwsArgumentError);
    }
  });

  test('legacy two-bracket tariff is unchanged', () {
    final legacy = TariffConfig.demo();
    expect(legacy.distanceChargeForKm(15), 14.5 * 14500);
  });
}
