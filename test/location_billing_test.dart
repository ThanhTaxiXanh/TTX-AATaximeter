import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';

void main() {
  final start = DateTime(2026, 11, 4, 8);

  test('skip untrusted time before GPS first fix without waiting fee', () {
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    meter.start(at: start);
    meter.skipUntrustedInterval(start.add(const Duration(seconds: 90)));
    expect(meter.elapsedSeconds, 0);
    expect(meter.waitingSeconds, 0);
    meter.tick(start.add(const Duration(seconds: 91)));
    expect(meter.elapsedSeconds, 1);
    expect(meter.waitingSeconds, 1);
  });

  test('invalid and outlier positions do not refresh trusted state', () {
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    meter.start(at: start);
    expect(meter.acceptGps(GpsFix(
      latitude: 21, longitude: 106, accuracyMeters: 5,
      speedKmh: 20, timestamp: start)), true);
    final distanceBefore = meter.distanceMeters;
    expect(meter.acceptGps(GpsFix(
      latitude: 25, longitude: 109, accuracyMeters: 5,
      speedKmh: 140,
      timestamp: start.add(const Duration(seconds: 1)))), false);
    expect(meter.distanceMeters, distanceBefore);
    expect(meter.speedKmh, 20);
    expect(meter.acceptGps(GpsFix(
      latitude: 21.0002, longitude: 106,
      accuracyMeters: 50, speedKmh: 12,
      timestamp: start.add(const Duration(seconds: 2)))), false);
  });

  test('interrupted trip is not billed during untrusted interval', () {
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    meter.start(at: start);
    meter.tick(start.add(const Duration(seconds: 2)));
    meter.skipUntrustedInterval(start.add(const Duration(minutes: 10)));
    meter.suspendForInterruption(
        at: start.add(const Duration(minutes: 10)));
    final before = meter.totalFare;
    final time = meter.elapsedSeconds;
    meter.tick(start.add(const Duration(hours: 3)));
    expect(meter.totalFare, before);
    expect(meter.elapsedSeconds, time);
  });
}
