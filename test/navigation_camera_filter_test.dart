import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/navigation_camera_filter.dart';

void main() {
  const nearHanoiLat = 21.0280;
  const nearHanoiLon = 105.8340;
  final start = DateTime.utc(2026, 11, 6, 13);

  test('stationary 3D camera ignores short GPS drift and heading jitter', () {
    final filter = NavigationCameraFilter();
    final first = filter.update(
      at: start, latitude: nearHanoiLat, longitude: nearHanoiLon,
      headingDegrees: 37, speedKmh: 0);
    final second = filter.update(
      at: start.add(const Duration(seconds: 1)),
      latitude: nearHanoiLat + 0.000012,
      longitude: nearHanoiLon + 0.000010,
      headingDegrees: 175, speedKmh: 1.5);
    expect(second.latitude, first.latitude);
    expect(second.longitude, first.longitude);
    expect(second.headingDegrees, first.headingDegrees);
  });

  test('heading interpolation uses the shortest arc across 360 degrees', () {
    final filter = NavigationCameraFilter();
    filter.update(
      at: start, latitude: nearHanoiLat, longitude: nearHanoiLon,
      headingDegrees: 359, speedKmh: 18);
    final following = filter.update(
      at: start.add(const Duration(milliseconds: 900)),
      latitude: nearHanoiLat + 0.000030,
      longitude: nearHanoiLon, headingDegrees: 1, speedKmh: 18);
    expect(following.headingDegrees < 10 ||
        following.headingDegrees > 350, isTrue);
    expect(NavigationCameraFilter.shortestHeadingDelta(359, 1), 2);
    expect(NavigationCameraFilter.shortestHeadingDelta(1, 359), -2);
  });

  test('moving car receives smooth camera fixes without changing originals',
      () {
    final filter = NavigationCameraFilter();
    filter.update(
      at: start, latitude: nearHanoiLat, longitude: nearHanoiLon,
      headingDegrees: 0, speedKmh: 12);
    const rawLatitude = nearHanoiLat + 0.0001;
    final next = filter.update(
      at: start.add(const Duration(milliseconds: 500)),
      latitude: rawLatitude, longitude: nearHanoiLon,
      headingDegrees: 20, speedKmh: 12);
    expect(next.latitude, greaterThan(nearHanoiLat));
    expect(next.latitude, lessThan(rawLatitude));
    expect(next.headingDegrees, greaterThan(0));
    expect(next.headingDegrees, lessThan(20));
    // All raw location inputs remain unchanged.
    expect(rawLatitude, nearHanoiLat + 0.0001);
  });

  test('sharp real turns are not excessively delayed', () {
    final filter = NavigationCameraFilter();
    filter.update(
      at: start, latitude: nearHanoiLat, longitude: nearHanoiLon,
      headingDegrees: 0, speedKmh: 25);
    final turn = filter.update(
      at: start.add(const Duration(seconds: 1)),
      latitude: nearHanoiLat + 0.00007,
      longitude: nearHanoiLon, headingDegrees: 90, speedKmh: 25);
    expect(turn.headingDegrees, greaterThan(65));
    expect(turn.headingDegrees, lessThanOrEqualTo(90));
  });

  test('reacquisition after GPS gap snaps rather than dragging map', () {
    final filter = NavigationCameraFilter();
    filter.update(
      at: start, latitude: nearHanoiLat, longitude: nearHanoiLon,
      headingDegrees: 5, speedKmh: 6);
    final afterGap = filter.update(
      at: start.add(const Duration(seconds: 12)),
      latitude: nearHanoiLat + 0.0005,
      longitude: nearHanoiLon, headingDegrees: 90, speedKmh: 20);
    expect(afterGap.latitude, nearHanoiLat + 0.0005);
    expect(afterGap.headingDegrees, 90);
  });

  test('resets on map style/mode switch and rejects invalid points', () {
    final filter = NavigationCameraFilter();
    filter.update(
      at: start, latitude: nearHanoiLat, longitude: nearHanoiLon,
      headingDegrees: 15, speedKmh: 4);
    filter.reset();
    final first = filter.update(
      at: start.add(const Duration(seconds: 1)),
      latitude: nearHanoiLat + 0.0002,
      longitude: nearHanoiLon, headingDegrees: 88, speedKmh: 0);
    expect(first.headingDegrees, 88);
    expect(() => filter.update(
      at: start.add(const Duration(seconds: 2)),
      latitude: 95, longitude: nearHanoiLon,
      headingDegrees: 0, speedKmh: 0), throwsFormatException);
  });
}
