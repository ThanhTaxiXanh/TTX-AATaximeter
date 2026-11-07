import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/platform/car_state_bridge.dart';

void main() {
  final start = DateTime(2026, 11, 7, 12);

  test('first native mirror is immediate, frequent identical state is gated', () {
    final gate = CarStatePublishGate();
    expect(gate.shouldPublish(start, status: 'idle', interrupted: false), true);
    gate.markPublished(start, status: 'idle', interrupted: false);
    expect(gate.shouldPublish(start.add(const Duration(seconds: 3)),
        status: 'idle', interrupted: false), false);
    expect(gate.shouldPublish(start.add(const Duration(seconds: 9)),
        status: 'idle', interrupted: false), false);
    expect(gate.shouldPublish(start.add(const Duration(seconds: 10)),
        status: 'idle', interrupted: false), true);
  });

  test('trip status and interruption are published immediately', () {
    final gate = CarStatePublishGate();
    gate.markPublished(start, status: 'running', interrupted: false);
    final shortlyAfter = start.add(const Duration(seconds: 1));
    expect(gate.shouldPublish(shortlyAfter,
        status: 'paused', interrupted: false), true);
    gate.markPublished(shortlyAfter, status: 'paused', interrupted: false);
    expect(gate.shouldPublish(shortlyAfter.add(const Duration(seconds: 1)),
        status: 'paused', interrupted: true), true);
    expect(gate.shouldPublish(shortlyAfter.add(const Duration(seconds: 1)),
        status: 'paused', interrupted: false), false);
  });

  test('failed publish is retryable and clock reversal fails open', () {
    final gate = CarStatePublishGate();
    expect(gate.shouldPublish(start, status: 'running', interrupted: false), true);
    // No markPublished because the channel failed: retries are allowed.
    expect(gate.shouldPublish(start.add(const Duration(seconds: 2)),
        status: 'running', interrupted: false), true);
    gate.markPublished(start.add(const Duration(seconds: 3)),
        status: 'running', interrupted: false);
    expect(gate.shouldPublish(start, status: 'running', interrupted: false), true);
  });
}
