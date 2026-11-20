import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';

void main() {
  test('25 percent viewport padding avoids repeat RTree queries on small pan', () {
    const initial = SignViewport(
      west: 105.8, east: 106.0, south: 21.0, north: 21.2);
    final coverage = initial.expanded();
    expect(coverage.isValid, true);
    expect(coverage.contains(initial), true);
    expect(coverage.contains(const SignViewport(
      west: 105.81, east: 106.01, south: 21.01, north: 21.21)), true);
    expect(coverage.contains(const SignViewport(
      west: 106.2, east: 106.4, south: 21.01, north: 21.21)), false);
  });

  test('padding clamps to valid earth bounds without wrapping', () {
    const full = SignViewport(
      west: -180, east: 180, south: -90, north: 90);
    final expanded = full.expanded();
    expect(expanded.isValid, true);
    expect(expanded.contains(full), true);
    expect(expanded.west, -180);
    expect(expanded.east, 180);
    const crossing = SignViewport(
      west: 170, east: -175, south: 0, north: 10);
    expect(crossing.isValid, false);
    expect(crossing.expanded().isValid, false);
  });
}
