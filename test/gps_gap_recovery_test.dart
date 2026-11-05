import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/location_tracking_policy.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';

void main() {
  final start = DateTime(2026, 11, 5, 8);
  GpsFix fix(DateTime at, {
    double lat = 21.0278,
    double lon = 105.8342,
    double accuracy = 5,
    double speed = 0,
  }) => GpsFix(latitude: lat, longitude: lon,
      accuracyMeters: accuracy, speedKmh: speed, timestamp: at);

  test('bad first GPS fix never becomes a trusted watchdog fix', () {
    final policy = LocationTrackingPolicy();
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    meter.start(at: start);
    policy.begin(start);
    final invalid = fix(start.add(const Duration(seconds: 2)),
        accuracy: 90);
    expect(meter.isValidGpsObservation(invalid), isFalse);
    expect(policy.hasTrustedFix, isFalse);
    expect(meter.distanceMeters, 0);
    expect(meter.waitingSeconds, 0);
    expect(meter.isValidGpsObservation(
        fix(start.add(const Duration(seconds: 3)))), isTrue);
  });

  test('GPS blackout recovery uses new baseline, never a straight jump', () {
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    final policy = LocationTrackingPolicy();
    meter.start(at: start);
    policy.begin(start);
    final first = fix(start.add(const Duration(seconds: 2)),
        speed: 30);
    expect(meter.acceptGps(first), isTrue);
    policy.acceptedFix(start.add(const Duration(seconds: 2)));
    meter.tick(start.add(const Duration(seconds: 3)));
    final gapEnd = start.add(const Duration(minutes: 2));
    expect(policy.shouldSuspend(gapEnd), isTrue);
    // Invalid samples do not justify clearing or billing a gap.
    final rejected = fix(gapEnd, lat: 22.0, accuracy: 200);
    expect(meter.isValidGpsObservation(rejected), isFalse);
    expect(meter.distanceMeters, 0);
    meter.skipUntrustedInterval(gapEnd);
    // First valid sample beyond the outage establishes a NEW location.
    final recovered = fix(gapEnd, lat: 22.0, speed: 0);
    expect(meter.acceptGps(recovered), isTrue);
    policy.acceptedFix(gapEnd);
    expect(meter.distanceMeters, 0);
    meter.tick(gapEnd.add(const Duration(seconds: 1)));
    expect(meter.waitingFare, 0);
  });
}
