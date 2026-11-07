import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/trip_session_snapshot.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';
import 'package:ttx_aataximeter/src/domain/trip_route_point.dart';

void main() {
  final start = DateTime(2026, 11, 5, 6);
  final route = [
    TripRoutePoint(latitude: 21.273, longitude: 106.193,
      accuracyMeters: 4, speedKmh: 23, recordedAt: start),
    TripRoutePoint(latitude: 21.274, longitude: 106.194,
      accuracyMeters: 4, speedKmh: 22, segment: 1,
      recordedAt: start.add(const Duration(seconds: 25))),
  ];

  test('route survives completed trip JSON and payment copyWith', () {
    final receipt = TripReceipt(
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 15)),
      distanceKm: 6.2, durationSeconds: 900, waitingSeconds: 0,
      baseFare: 30000, distanceFare: 70000, waitingFare: 0,
      tollFee: 0, surcharge: 0, discount: 0,
      totalFare: 100000, isFlatFare: false,
    );
    final trip = TripRecord.fromReceipt(receipt, routePoints: route);
    final decoded = TripRecord.decode(trip.encode());
    expect(decoded.routePoints.length, 2);
    expect(decoded.routePoints.last.segment, 1);
    expect(decoded.copyWith(
      paymentMethod: PaymentMethod.bankTransfer).routePoints.length, 2);
  });

  test('route survives checkpoint and recovery', () {
    final engine = TaximeterEngine(tariff: TariffConfig.demo());
    engine.start(at: start);
    final snapshot = TripSessionSnapshot.fromEngine(engine,
      routePoints: route).encode();
    final loaded = TripSessionSnapshot.decode(snapshot);
    expect(loaded.routePoints.length, 2);
    expect(loaded.routePoints.first.latitude, 21.273);
    expect(loaded.restore().requiresManualResume, true);
  });

  test('legacy trips and snapshots without route are readable', () {
    final trip = TripRecord.fromJson({
      'startedAt': start.toIso8601String(),
      'endedAt': start.toIso8601String(),
    });
    expect(trip.routePoints, isEmpty);
    final engine = TaximeterEngine(tariff: TariffConfig.demo());
    engine.start(at: start);
    final snapshot = TripSessionSnapshot.fromEngine(engine).encode();
    expect(TripSessionSnapshot.decode(snapshot).routePoints, isEmpty);
  });

  test('reject fabricated GPS coordinates when decoding route', () {
    expect(() => TripRoutePoint.fromJson({
      'lat': 999, 'lon': 106, 'accuracy': 5, 'speed': 10,
      'segment': 0, 'at': start.toIso8601String(),
    }), throwsFormatException);
  });

  test('watchdog gap allows a fresh baseline without distance jump', () {
    final engine = TaximeterEngine(tariff: TariffConfig.demo());
    engine.start(at: start);
    final first = GpsFix(latitude: 21.273, longitude: 106.193,
      accuracyMeters: 5, speedKmh: 20, timestamp: start);
    expect(engine.acceptGps(first), true);
    engine.tick(start.add(const Duration(seconds: 2)));
    final before = engine.distanceMeters;
    final resumedAt = start.add(const Duration(minutes: 12));
    engine.skipUntrustedInterval(resumedAt);
    expect(engine.acceptGps(GpsFix(
      latitude: 21.38, longitude: 106.3, accuracyMeters: 5,
      speedKmh: 30, timestamp: resumedAt)), true);
    expect(engine.distanceMeters, before);
    expect(engine.elapsedSeconds, 2);
  });
}
