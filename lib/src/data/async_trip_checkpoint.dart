import 'package:flutter/foundation.dart';

import 'trip_session_snapshot.dart';

/// Above this number of route vertices, JSON conversion is moved off the
/// UI isolate. The immutable snapshot was captured before enqueueing, so
/// checkpoint ordering and exact fare/route content are preserved.
const int isolateCheckpointRouteThreshold = 160;

String _encodeInWorker(TripSessionSnapshot snapshot) => snapshot.encode();

Future<String> encodeTripCheckpoint(TripSessionSnapshot snapshot) async {
  if (snapshot.routePoints.length < isolateCheckpointRouteThreshold) {
    // Avoid isolate startup overhead for short trips.
    return snapshot.encode();
  }
  return compute(_encodeInWorker, snapshot);
}
