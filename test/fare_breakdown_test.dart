import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/fare_breakdown.dart';

void main() {
  final price = TariffConfig.demo().copyWith(
    baseFare: 30000, baseDistanceKm: 1.5,
    fareTiers: const [
      FareTier(upToKm: 30, ratePerKm: 15000),
      FareTier(upToKm: 45, ratePerKm: 12500),
      FareTier(upToKm: null, ratePerKm: 10000),
    ],
  );

  test('30k opening until 1.5km, 1.5-30km band length 28.5km', () {
    final rows = calculateFareBreakdown(
      tariff: price, distanceKm: .05, tripStarted: true);
    expect(rows[0].amount, 30000);
    expect(rows[0].traveledKm, closeTo(.05, .000001));
    expect(rows[1].fromKm, 1.5);
    expect(rows[1].toKm, 30);
    expect(rows[1].capacityKm, 28.5);
    expect(rows[1].traveledKm, 0);
    expect(rows[1].amount, 0);
  });

  test('10km: only 8.5km billed at tier 1 rate', () {
    final rows = calculateFareBreakdown(
      tariff: price, distanceKm: 10, tripStarted: true);
    expect(rows[1].traveledKm, 8.5);
    expect(rows[1].amount, 127500);
    expect(rows[2].amount, 0);
    expect(rows.fold<double>(0, (s, e) => s + e.amount),
      price.baseFare + price.distanceChargeForKm(10));
  });

  test('35km: 28.5km complete, then 5km, later zero', () {
    final rows = calculateFareBreakdown(
      tariff: price, distanceKm: 35, tripStarted: true);
    expect(rows[1].traveledKm, 28.5);
    expect(rows[1].amount, 427500);
    expect(rows[2].traveledKm, 5);
    expect(rows[2].amount, 62500);
    expect(rows[3].traveledKm, 0);
    expect(rows.fold<double>(0, (s, e) => s + e.amount),
      price.baseFare + price.distanceChargeForKm(35));
  });

  test('idle: no opening fare or extra fare collected', () {
    final rows = calculateFareBreakdown(
      tariff: price, distanceKm: 0, tripStarted: false);
    expect(rows.every((row) => row.amount == 0), isTrue);
  });

  test('50km: final open-ended tier starts 45km', () {
    final rows = calculateFareBreakdown(
      tariff: price, distanceKm: 50, tripStarted: true);
    expect(rows.last.capacityKm, isNull);
    expect(rows.last.fromKm, 45);
    expect(rows.last.traveledKm, 5);
    expect(rows.last.amount, 50000);
  });
}
