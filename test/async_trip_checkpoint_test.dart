import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/async_trip_checkpoint.dart';
import 'package:ttx_aataximeter/src/data/trip_session_snapshot.dart';
import 'package:ttx_aataximeter/src/domain/trip_route_point.dart';

void main() {
  final origin = DateTime(2026, 11, 5, 8);
  final tariff = TariffConfig.demo();

  TripSessionSnapshot snapshotWithPoints(int count) {
    final engine = TaximeterEngine(tariff: tariff)..start(at: origin);
    return TripSessionSnapshot.fromEngine(
      engine,
      pickup: 'Điểm đón',
      dropoff: 'Điểm đến',
      fareProfileName: tariff.name,
      routePoints: List.generate(count, (i) => TripRoutePoint(
        latitude: 21.028 + i * 0.00001,
        longitude: 105.834 + i * 0.00001,
        recordedAt: origin.add(Duration(seconds: i * 5)),
        accuracyMeters: 4,
        speedKmh: 18,
        segment: i < count ~/ 2 ? 0 : 1,
      )),
    );
  }

  test('short trip encodes without background worker and preserves JSON', () async {
    final original = snapshotWithPoints(3);
    final encoded = await encodeTripCheckpoint(original);
    expect(jsonDecode(encoded), jsonDecode(original.encode()));
    final recovered = TripSessionSnapshot.decode(encoded);
    expect(recovered.routePoints.length, 3);
    expect(recovered.dropoff, 'Điểm đến');
  });

  test('long route encodes in isolate without losing points or fare', () async {
    final original = snapshotWithPoints(isolateCheckpointRouteThreshold + 10);
    final encoded = await encodeTripCheckpoint(original);
    expect(jsonDecode(encoded), jsonDecode(original.encode()));
    final recovered = TripSessionSnapshot.decode(encoded);
    expect(recovered.routePoints.length, isolateCheckpointRouteThreshold + 10);
    expect(recovered.routePoints.first.segment, 0);
    expect(recovered.routePoints.last.segment, 1);
    expect(recovered.restore().requiresManualResume, true);
  });
}
