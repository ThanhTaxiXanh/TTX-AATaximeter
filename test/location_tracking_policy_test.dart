import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/location_tracking_policy.dart';

void main() {
  final start = DateTime(2026, 11, 4, 8);
  test('never assume an uninitialized stream has valid GPS', () {
    final gate = LocationTrackingPolicy();
    expect(gate.isMonitoring, false);
    expect(gate.hasRecentFix(start), false);
    expect(gate.shouldSuspend(start), false);
    expect(gate.canLeaveForeground(start, streamSubscribed: true), false);
  });

  test('start waits for fix but stops after acquisition timeout', () {
    final gate = LocationTrackingPolicy();
    gate.begin(start);
    expect(gate.hasRecentFix(start), false);
    expect(gate.shouldSuspend(start.add(const Duration(seconds: 29))), false);
    expect(gate.shouldSuspend(start.add(const Duration(seconds: 31))), true);
    gate.acceptedFix(start.add(const Duration(seconds: 31)));
    expect(gate.shouldSuspend(start.add(const Duration(seconds: 32))), false);
  });

  test('GPS freshness must survive background transition', () {
    final gate = LocationTrackingPolicy();
    gate.begin(start);
    gate.acceptedFix(start.add(const Duration(seconds: 2)));
    expect(gate.canLeaveForeground(start.add(const Duration(seconds: 10)),
        streamSubscribed: true), true);
    expect(gate.canLeaveForeground(start.add(const Duration(seconds: 10)),
        streamSubscribed: false), false);
    expect(gate.shouldSuspend(start.add(const Duration(seconds: 13))), false);
    expect(gate.shouldSuspend(start.add(const Duration(seconds: 15))), true);
  });

  test('clock reversals never make future fixes count as recent', () {
    final gate = LocationTrackingPolicy();
    gate.begin(start);
    gate.acceptedFix(start.add(const Duration(seconds: 20)));
    expect(gate.hasRecentFix(start.add(const Duration(seconds: 19))), false);
    gate.acceptedFix(start.add(const Duration(seconds: 1)));
    expect(gate.lastTrustedFixAt, start.add(const Duration(seconds: 20)));
    gate.clear();
    expect(gate.isMonitoring, false);
  });
}
