import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/map_presentation_gate.dart';

void main() {
  test('first map frame is painted; identical fixes are not rebuilt', () {
    final gate = MapPresentationGate();
    bool push({double? lat = 21, double? lon = 105,
        double heading = 90, double speed = 0, int count = 0,
        bool force = false}) =>
      gate.shouldPublish(
        latitude: lat, longitude: lon,
        headingDegrees: heading, speedKmh: speed,
        routePointCount: count, force: force);

    expect(push(), isTrue);
    expect(push(), isFalse);
    expect(push(lat: 21.000001, lon: 105.000001), isFalse);
    expect(push(speed: 0.4), isFalse);
    expect(gate.observed, 4);
    expect(gate.published, 1);
  });

  test('significant GPS displacement, speed and new GPS route point repaint', () {
    final gate = MapPresentationGate();
    bool push(double lat, double speed, int count) =>
      gate.shouldPublish(
        latitude: lat, longitude: 105,
        headingDegrees: 90, speedKmh: speed,
        routePointCount: count);

    expect(push(21, 0, 0), isTrue);
    expect(push(21.000001, 0, 0), isFalse);
    expect(push(21.000005, 0, 0), isTrue);
    expect(push(21.000005, 0.9, 0), isTrue);
    expect(push(21.000005, 0.9, 1), isTrue);
    expect(push(21.000005, 0.9, 1), isFalse);
    expect(gate.published, 4);
  });

  test('bearings wrap correctly; tiny angle jitter is coalesced', () {
    final gate = MapPresentationGate();
    bool push(double heading) => gate.shouldPublish(
      latitude: 21, longitude: 105, headingDegrees: heading,
      speedKmh: 0, routePointCount: 0);
    expect(push(359), isTrue);
    expect(push(0), isFalse);
    expect(push(361), isFalse);
    expect(push(3), isTrue);
    expect(push(363.5), isFalse);
    expect(push(9), isTrue);
  });

  test('null fix, resumed frame and forced style refresh are handled', () {
    final gate = MapPresentationGate();
    bool push(double? latitude, {bool force = false}) =>
      gate.shouldPublish(
        latitude: latitude, longitude: latitude == null ? null : 105,
        headingDegrees: 0, speedKmh: 0,
        routePointCount: 0, force: force);
    expect(push(null), isTrue);
    expect(push(null), isFalse);
    expect(push(21), isTrue);
    expect(push(null), isTrue);
    expect(push(null, force: true), isTrue);
    gate.reset();
    expect(push(null), isTrue);
  });

  test('rebuild filtering cannot modify GPS history or meter values', () {
    final gate = MapPresentationGate();
    final originalRawFixes = <double>[21.000000, 21.000001, 21.000002];
    for (final lat in originalRawFixes) {
      gate.shouldPublish(latitude: lat, longitude: 105,
        headingDegrees: 0, speedKmh: 0, routePointCount: 0);
    }
    expect(originalRawFixes, [21.000000, 21.000001, 21.000002]);
    expect(gate.observed, 3);
    expect(gate.published, 1);
  });
}
