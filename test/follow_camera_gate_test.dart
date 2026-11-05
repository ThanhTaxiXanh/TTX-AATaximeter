import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/follow_camera_gate.dart';

void main() {
  test('stationary camera and GPS jitter do not trigger animations', () {
    final gate = FollowCameraGate();
    final now = DateTime(2026, 11, 5, 8);
    bool check(DateTime at, double latitude, double bearing,
        {bool force = false}) => gate.shouldUpdate(
      at: at,
      latitude: latitude,
      longitude: 105.8342,
      bearing: bearing,
      zoom: 17,
      force: force,
    );
    expect(check(now, 21.0278, 10), isTrue);
    // A callback in the middle of an animation cannot start another.
    expect(check(now.add(const Duration(milliseconds: 150)),
      21.028, 20), isFalse);
    expect(check(now.add(const Duration(milliseconds: 500)),
      21.027802, 11), isFalse);
    expect(check(now.add(const Duration(seconds: 2)),
      21.0278, 10), isFalse);
    // Movement of ~11m should update the camera, but not the fare engine.
    expect(check(now.add(const Duration(seconds: 3)),
      21.0279, 10), isTrue);
    // User pressing center is always allowed to reposition.
    expect(check(now.add(const Duration(seconds: 3, milliseconds: 50)),
      21.0279, 10, force: true), isTrue);
  });

  test('bearing wrap, zoom changes and style reset are handled', () {
    final gate = FollowCameraGate(minimumBearingDegrees: 4);
    final now = DateTime(2026, 11, 5, 8);
    bool check(DateTime at, double heading, {double zoom = 17}) =>
        gate.shouldUpdate(at: at,
          latitude: 21.0278, longitude: 105.8342,
          bearing: heading, zoom: zoom);
    expect(check(now, 359), isTrue);
    expect(check(now.add(const Duration(seconds: 1)), 1), isFalse);
    expect(check(now.add(const Duration(seconds: 2)), 8), isTrue);
    expect(check(now.add(const Duration(seconds: 3)), 8, zoom: 18), isTrue);
    gate.reset();
    expect(check(now.add(const Duration(seconds: 4)), 8), isTrue);
  });

  test('invalid coordinates never create a native camera operation', () {
    final gate = FollowCameraGate();
    expect(gate.shouldUpdate(
      at: DateTime(2026), latitude: 91, longitude: 106,
      bearing: 0, zoom: 17), isFalse);
    expect(gate.shouldUpdate(
      at: DateTime(2026), latitude: 21, longitude: 106,
      bearing: 0, zoom: 17), isTrue);
  });
}
