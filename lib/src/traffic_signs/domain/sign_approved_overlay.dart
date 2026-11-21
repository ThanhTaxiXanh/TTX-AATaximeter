import 'traffic_sign.dart';
import '../moderation/sign_review_store.dart';

/// Merge a bounded viewport selection with explicitly approved local patches.
/// Uses weighted grid aggregation so TOTAL == sum(marker.count) even after
/// edits and tombstones in the original immutable source database.
abstract final class SignApprovedOverlay {
  static SignViewportResult merge(
      SignViewportResult source,
      List<ApprovedSignPatch> patches,
      SignViewport bounds,
      TrafficSignFilter filter,
      {int maxMarkers = 320}) {
    final approved = patches.where((p) => p.visibleIn(bounds, filter))
        .map((p) => p.toMapItem()).toList(growable: false);
    if (approved.isEmpty) return source;
    final all = <SignMapItem>[...source.items, ...approved];
    final total = source.total + approved.length;
    if (all.length <= maxMarkers) {
      return SignViewportResult(total: total, items: all);
    }
    final lonStep = ((bounds.east - bounds.west) / 15)
        .clamp(0.000001, 360.0);
    final latStep = ((bounds.north - bounds.south) / 15)
        .clamp(0.000001, 180.0);
    final groups = <(int, int), _SignAccumulator>{};
    for (final item in all) {
      final x = ((item.longitude - bounds.west) / lonStep).floor()
          .clamp(0, 14);
      final y = ((item.latitude - bounds.south) / latStep).floor()
          .clamp(0, 14);
      groups.putIfAbsent((x, y), _SignAccumulator.new).add(item);
    }
    final result = groups.values.map((g) => g.toItem())
        .toList(growable: false);
    if (result.length > maxMarkers ||
        result.fold<int>(0, (v, item) => v + item.count) != total) {
      throw StateError('Approved sign aggregation count mismatch');
    }
    return SignViewportResult(total: total, items: result);
  }
}

class _SignAccumulator {
  int count = 0;
  int? firstId;
  double weightedLon = 0, weightedLat = 0;
  int? typeCode, rawValue, inferred;

  void add(SignMapItem item) {
    count += item.count;
    firstId = firstId == null || item.signId < firstId!
        ? item.signId : firstId;
    weightedLon += item.longitude * item.count;
    weightedLat += item.latitude * item.count;
    if (count == 1) {
      typeCode = item.signTypeCode;
      rawValue = item.valueRaw;
      inferred = item.speedKmhInferred;
    } else {
      typeCode = null;
      rawValue = null;
      inferred = null;
    }
  }

  SignMapItem toItem() => SignMapItem(
    signId: firstId!, count: count,
    longitude: weightedLon / count, latitude: weightedLat / count,
    signTypeCode: count == 1 ? typeCode : null,
    valueRaw: count == 1 ? rawValue : null,
    speedKmhInferred: count == 1 ? inferred : null,
  );
}
