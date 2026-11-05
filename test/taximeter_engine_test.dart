import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';

void main() {
  const tariff = TariffConfig(
    baseFare: 12000, baseDistanceKm: 1, perKmRate: 15000,
    longDistanceThresholdKm: 10, longDistancePerKmRate: 10000,
    waitingFeePerHour: 36000, waitingGraceMinutes: 0,
    roundToThousands: false,
  );

  test('opening fare and 2-tier distance', () {
    final m = TaximeterEngine(tariff: tariff);
    m.start(at: DateTime(2026));
    expect(m.totalFare, 12000);
    m.distanceMeters = 1000;
    expect(m.distanceFare, 0);
    m.distanceMeters = 2000;
    expect(m.distanceFare, 15000);
    m.distanceMeters = 12000;
    expect(m.distanceFare, 9 * 15000 + 2 * 10000);
  });

  test('tick counts waiting while paused and under speed threshold', () {
    final m = TaximeterEngine(tariff: tariff);
    final start = DateTime(2026);
    m.start(at: start);
    m.tick(start.add(const Duration(seconds: 15)));
    expect(m.waitingSeconds, 15);
    m.pause(at: start.add(const Duration(seconds: 15)));
    m.tick(start.add(const Duration(seconds: 45)));
    expect(m.elapsedSeconds, 45);
    expect(m.waitingFare, 450);
    m.resume(at: start.add(const Duration(seconds: 45)));
  });

  test('five-minute stop does not charge waiting until second 301', () {
    final m = TaximeterEngine(tariff: tariff.copyWith(
      waitingGraceMinutes: 5));
    final start = DateTime(2026);
    m.start(at: start);
    m.tick(start.add(const Duration(seconds: 299)));
    expect(m.waitingSeconds, 0);
    expect(m.waitingFare, 0);
    m.tick(start.add(const Duration(minutes: 5)));
    expect(m.waitingSeconds, 0);
    m.tick(start.add(const Duration(seconds: 301)));
    expect(m.waitingSeconds, 1);
    expect(m.waitingFare, 10);
    m.tick(start.add(const Duration(minutes: 6)));
    expect(m.waitingSeconds, 60);
  });

  test('moving resets stop timer and GPS gap does not count', () {
    final m = TaximeterEngine(tariff: tariff.copyWith(
      waitingGraceMinutes: 5));
    final start = DateTime(2026);
    m.start(at: start);
    m.tick(start.add(const Duration(minutes: 4)));
    expect(m.waitingSeconds, 0);
    m.speedKmh = 25;
    m.tick(start.add(const Duration(minutes: 5)));
    m.speedKmh = 0;
    m.tick(start.add(const Duration(minutes: 9)));
    expect(m.waitingSeconds, 0);
    m.skipUntrustedInterval(start.add(const Duration(minutes: 12)));
    m.tick(start.add(const Duration(minutes: 16)));
    expect(m.waitingSeconds, 0);
    m.tick(start.add(const Duration(minutes: 18)));
    expect(m.waitingSeconds, 60);
  });

  test('flat fare excludes distance/wait but includes extra charges', () {
    final m = TaximeterEngine(tariff: tariff);
    m.start(at: DateTime(2026), fixedFare: 250000);
    m.addToll(30000);
    m.setAdjustments(surchargeFee: 5000);
    expect(m.totalFare, 285000);
  });

  test('rejects outlier GPS and honors normal travel', () {
    final m = TaximeterEngine(tariff: tariff);
    final start = DateTime(2026);
    m.start(at: start);
    m.acceptGps(GpsFix(latitude: 21, longitude: 106,
      accuracyMeters: 5, speedKmh: 30, timestamp: start));
    m.acceptGps(GpsFix(latitude: 21.0009, longitude: 106,
      accuracyMeters: 5, speedKmh: 30,
      timestamp: start.add(const Duration(seconds: 10))));
    expect(m.distanceMeters, greaterThan(95));
    final existing = m.distanceMeters;
    m.acceptGps(GpsFix(latitude: 25, longitude: 109,
      accuracyMeters: 5, speedKmh: 140,
      timestamp: start.add(const Duration(seconds: 11))));
    expect(m.distanceMeters, existing);
  });

  test('finish saves a receipt; reset allows next trip', () {
    final m = TaximeterEngine(tariff: tariff);
    final start = DateTime(2026);
    m.start(at: start);
    final receipt = m.finish(at: start.add(const Duration(minutes: 1)));
    expect(receipt.durationSeconds, 60);
    expect(m.status, MeterStatus.finished);
    m.reset();
    expect(m.status, MeterStatus.idle);
    expect(m.totalFare, 0);
  });

  test('rounding 1000 can be switched on', () {
    final m = TaximeterEngine(tariff: tariff.copyWith(
      baseFare: 12549, roundToThousands: true));
    m.start(at: DateTime(2026));
    expect(m.totalFare, 13000);
  });
}
