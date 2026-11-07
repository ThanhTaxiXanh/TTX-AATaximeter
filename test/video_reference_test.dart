import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/quote_calculator.dart';

void main() {
  test('video 1: observed city four-seat preset matches recorded values', () {
    final tariff = TariffConfig.demo();
    expect(tariff.baseFare, 12000);
    expect(tariff.baseDistanceKm, 0.5);
    expect(tariff.perKmRate, 14500);
    expect(tariff.longDistanceThresholdKm, 30);
    expect(tariff.longDistancePerKmRate, 12000);
    expect(tariff.waitingFeePerHour, 30000);
    expect(tariff.waitingSpeedThresholdKmh, 5);
    expect(tariff.speedLimitKmh, 80);
    expect(tariff.roundToThousands, isTrue);
  });

  test('video 2: 15km one-way quote => 222000 VND', () {
    final t = TariffConfig.demo();
    final quote = const QuoteCalculator().estimate(
      tariff: t, distanceKm: 15,
      perKmRate: 14500, tollFee: 0,
    );
    expect(quote, 222000);
  });

  test('GPS and tariff unaffected by quote model', () {
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    meter.start(at: DateTime(2026));
    meter.distanceMeters = 15000;
    expect(meter.totalFare, 222000);
  });
}
