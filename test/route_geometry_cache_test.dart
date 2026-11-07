import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/trip_route_point.dart';
import 'package:ttx_aataximeter/src/ui/route_render_geometry.dart';

TripRoutePoint sample(int i, {int segment = 0}) => TripRoutePoint(
  latitude: 21.0 + i * 0.00001 +
      (i % 71 == 0 ? 0.00005 : 0),
  longitude: 105.0 + (i ~/ 130) * 0.00025 +
      (i % 9) * 0.000001,
  speedKmh: 22.0, accuracyMeters: 5,
  recordedAt: DateTime.utc(2026).add(Duration(seconds: i)),
  segment: segment,
);

void verifyEqualGeometry(List<List<TripRoutePoint>> a,
    List<List<TripRoutePoint>> b) {
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    expect(a[i].length, b[i].length,
        reason: 'Mismatch in segment $i');
    for (var j = 0; j < a[i].length; j++) {
      expect(identical(a[i][j], b[i][j]), isTrue,
          reason: 'Vertex $j in segment $i must refer to the same raw fix');
    }
  }
}

void main() {
  test('incremental cache exactly matches original geometry at every boundary',
      () {
    final cache = RouteRenderGeometryCache();
    final route = <TripRoutePoint>[];
    const checkpoints = <int>{
      0, 1, 2, 63, 64, 65, 127, 128, 129, 749, 750, 751,
      752, 767, 768, 769, 832, 833, 1000, 1055, 1300, 2000,
    };
    for (var i = 0; i <= 2000; i++) {
      if (i > 0) route.add(sample(i));
      if (checkpoints.contains(i)) {
        final rendered = cache.render(route);
        verifyEqualGeometry(rendered, displayRouteSegments(route));
        expect(identical(cache.render(route), rendered), isTrue,
            reason: 'Unchanged mutable source must reuse rendered geometry');
      }
    }
    expect(route.length, 2000);
  });

  test('different segments, GPS gaps and nonconsecutive segment ids', () {
    final route = <TripRoutePoint>[];
    final cache = RouteRenderGeometryCache();
    for (var i = 0; i < 1200; i++) {
      route.add(sample(i, segment: i < 800 ? 2 : 17));
    }
    verifyEqualGeometry(
      cache.render(route), displayRouteSegments(route));
    for (var i = 1200; i < 1430; i++) {
      route.add(sample(i, segment: 17));
    }
    verifyEqualGeometry(
      cache.render(route), displayRouteSegments(route));
    // Out-of-order segment IDs still behave like the original map grouping.
    route.add(sample(1430, segment: 2));
    verifyEqualGeometry(
      cache.render(route), displayRouteSegments(route));
  });

  test('truncated and replaced routes rebuild safely', () {
    final cache = RouteRenderGeometryCache();
    final points = List.generate(870, sample);
    verifyEqualGeometry(
      cache.render(points), displayRouteSegments(points));
    points.removeRange(40, points.length);
    verifyEqualGeometry(
      cache.render(points), displayRouteSegments(points));
    points.addAll(List.generate(790, (i) => sample(i + 40)));
    verifyEqualGeometry(
      cache.render(points), displayRouteSegments(points));
    // A new route container is the contract for prefix replacements.
    final different = List<TripRoutePoint>.of(points);
    different[100] = sample(9000);
    verifyEqualGeometry(
      cache.render(different), displayRouteSegments(different));
    cache.reset();
    verifyEqualGeometry(
      cache.render(different), displayRouteSegments(different));
  });

  test('custom visual tolerance and threshold invalidate cached geometry', () {
    final cache = RouteRenderGeometryCache();
    final route = List.generate(999, sample);
    final a = cache.render(route, simplifyAbove: 750);
    final b = cache.render(route,
      simplifyAbove: 200, toleranceMeters: 6);
    verifyEqualGeometry(b, displayRouteSegments(route,
      simplifyAbove: 200, toleranceMeters: 6));
    expect(identical(a, b), isFalse);
    expect(() => cache.render(route, simplifyAbove: -1),
      throwsArgumentError);
    expect(() => cache.render(route, toleranceMeters: -1),
      throwsArgumentError);
  });
}
