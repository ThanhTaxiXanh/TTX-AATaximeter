import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/trip_route_point.dart';
import 'package:ttx_aataximeter/src/ui/route_render_geometry.dart';

TripRoutePoint point(int index, {int segment = 0,
    double? lat, double? lon}) => TripRoutePoint(
  latitude: lat ?? (21 + index * 0.00001),
  longitude: lon ?? 105,
  recordedAt: DateTime.utc(2026, 11, 7).add(Duration(seconds: index)),
  accuracyMeters: 5, speedKmh: 20, segment: segment,
);

void main() {
  test('short route remains byte-for-byte equivalent in geometry', () {
    final raw = [point(0), point(1), point(2), point(3)];
    final visual = displayRouteSegments(raw);
    expect(visual.length, 1);
    expect(visual.single.length, raw.length);
    for (var i = 0; i < raw.length; i++) {
      expect(identical(visual.single[i], raw[i]), isTrue);
    }
  });

  test('large straight route draws fewer points without modifying source', () {
    final raw = List.generate(4000, (i) => point(i));
    final visual = displayRouteSegments(raw);
    expect(visual.single.length, lessThan(250));
    expect(identical(visual.single.first, raw.first), isTrue);
    expect(identical(visual.single.last, raw.last), isTrue);
    expect(raw.length, 4000);
    expect(raw[2000].recordedAt, point(2000).recordedAt);
  });

  test('sharp turn and GPS gap retain endpoints and separate lines', () {
    final first = List.generate(1000, (i) => point(
      i,
      lat: i <= 500 ? 21 : 21 + (i - 500) * 0.00001,
      lon: 105 + (i <= 500 ? i : 500) * 0.00001,
    ));
    final second = List.generate(900, (i) => point(
      1000 + i, segment: 2,
      lat: 22 + i * 0.00001, lon: 106,
    ));
    final route = [...first, ...second];
    final visual = displayRouteSegments(route);
    expect(visual.length, 2);
    expect(identical(visual[0].first, first.first), isTrue);
    expect(identical(visual[0].last, first.last), isTrue);
    expect(visual[0].any((p) => identical(p, first[500])), isTrue);
    expect(identical(visual[1].first, second.first), isTrue);
    expect(identical(visual[1].last, second.last), isTrue);
    expect(visual[0].every((p) => p.segment == 0), isTrue);
    expect(visual[1].every((p) => p.segment == 2), isTrue);
    expect(route.length, 1900);
  });

  test('one point segments cannot draw a spurious line', () {
    final route = [point(0), point(1, segment: 1),
      point(2, segment: 1), point(3, segment: 4)];
    final visual = displayRouteSegments(route);
    expect(visual.length, 1);
    expect(visual.single.map((x) => x.segment).toList(), [1, 1]);
  });
}
