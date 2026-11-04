import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/revenue_summary.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';

TripRecord sample(DateTime at, {double fare = 10000,
    double km = 1, int duration = 300}) {
  final receipt = TripReceipt(
    startedAt: at, endedAt: at.add(Duration(seconds: duration)),
    distanceKm: km, durationSeconds: duration, waitingSeconds: 0,
    baseFare: fare, distanceFare: 0, waitingFare: 0, tollFee: 0,
    surcharge: 0, discount: 0, totalFare: fare, isFlatFare: false,
  );
  return TripRecord.fromReceipt(receipt);
}

void main() {
  final now = DateTime(2026, 11, 5, 9);
  final records = [
    sample(DateTime(2026, 11, 5, 7), fare: 20000, km: 2),
    sample(DateTime(2026, 11, 4, 14), fare: 50000, km: 5),
    sample(DateTime(2026, 11, 1), fare: 40000, km: 4),
    sample(DateTime(2026, 10, 10), fare: 30000, km: 3),
    sample(DateTime(2026, 11, 5, 8),
      fare: 0, km: 0, duration: 0),
    sample(DateTime(2026, 11, 6), fare: 60000, km: 6),
  ];

  test('date filters reflect today, Monday-start week, month, all', () {
    final today = RevenueSummary.calculate(records,
      period: RevenuePeriod.today, now: now);
    expect(today.tripCount, 1);
    expect(today.totalFare, 20000);
    expect(today.averageFare, 20000);

    final week = RevenueSummary.calculate(records,
      period: RevenuePeriod.week, now: now);
    expect(week.tripCount, 2);
    expect(week.totalFare, 70000);
    expect(week.totalDistanceKm, 7);
    expect(week.averageFare, 35000);

    final month = RevenueSummary.calculate(records,
      period: RevenuePeriod.month, now: now);
    expect(month.tripCount, 3);
    expect(month.totalFare, 110000);
    expect(month.totalDistanceKm, 11);

    final all = RevenueSummary.calculate(records,
      period: RevenuePeriod.all, now: now);
    expect(all.tripCount, 4);
    expect(all.totalFare, 140000);
  });

  test('empty report handles zero-count without division by zero', () {
    final result = RevenueSummary.calculate(const [],
      period: RevenuePeriod.all, now: now);
    expect(result.tripCount, 0);
    expect(result.averageFare, 0);
  });

  test('legitimate free trip with tracked distance is preserved', () {
    final result = RevenueSummary.calculate([
      sample(DateTime(2026, 11, 5, 8), fare: 0, km: 3),
    ], period: RevenuePeriod.today, now: now);
    expect(result.tripCount, 1);
    expect(result.totalFare, 0);
  });
}
