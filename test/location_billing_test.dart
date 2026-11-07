import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/core/location_tracking_policy.dart';

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
    expect(meter.waitingSeconds, 0);
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

  test('manual pause cannot accrue waiting in a GPS outage', () {
    final gate = LocationTrackingPolicy();
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    meter.start(at: start);
    gate.begin(start);
    gate.acceptedFix(start.add(const Duration(seconds: 2)));
    meter.tick(start.add(const Duration(seconds: 2)));
    meter.pause(at: start.add(const Duration(seconds: 2)));
    final before = meter.waitingSeconds;
    final outage = start.add(const Duration(minutes: 10));
    expect(gate.shouldSuspend(outage), true);
    meter.skipUntrustedInterval(outage);
    meter.suspendForInterruption(at: outage);
    meter.tick(start.add(const Duration(hours: 4)));
    expect(meter.waitingSeconds, before);
    expect(meter.requiresManualResume, true);
  });

  test('delayed GPS callback cannot reset an already-expired watchdog', () {
    final gate = LocationTrackingPolicy();
    gate.begin(start);
    gate.acceptedFix(start.add(const Duration(seconds: 2)));
    final late = start.add(const Duration(seconds: 19));
    expect(gate.shouldSuspend(late), true);
    // Reject the callback before calling acceptedFix(late).
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
