import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/fare_breakdown.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';

void main() {
  test('no tiers shown before start; tiers unlock at exact cutoffs', () {
    final price = TariffConfig.demo().copyWith(
      baseDistanceKm: 1.5, baseFare: 30000,
      fareTiers: const [
        FareTier(upToKm: 30, ratePerKm: 15000),
        FareTier(upToKm: null, ratePerKm: 12000),
      ],
    );
    expect(reachedFareLines(
      tariff: price, distanceKm: 0, tripStarted: false), isEmpty);
    expect(reachedFareLines(
      tariff: price, distanceKm: 0, tripStarted: true).length, 1);
    expect(reachedFareLines(
      tariff: price, distanceKm: 1.49, tripStarted: true).length, 1);
    expect(reachedFareLines(
      tariff: price, distanceKm: 1.5, tripStarted: true).length, 2);
    expect(reachedFareLines(
      tariff: price, distanceKm: 30, tripStarted: true).length, 3);
  });
}
