import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/sign_approved_overlay.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';
import 'package:ttx_aataximeter/src/traffic_signs/moderation/sign_review_store.dart';

void main() {
  const viewport = SignViewport(
      west: 105.0, east: 106.0, south: 21.0, north: 22.0);
  const filter = TrafficSignFilter(enabled: true);

  ApprovedSignPatch patch(int id, double lon, double lat,
      {int code = 4, int raw = 0, bool deleted = false}) =>
      ApprovedSignPatch(
        signId: id, longitude: lon, latitude: lat,
        typeCode: code, valueRaw: raw, directionRaw: 255,
        deleted: deleted, revision: 1,
      );

  test('approved overlays are merged, tombstones and outside points omitted',
      () {
    const source = SignViewportResult(
      total: 1, items: [
        SignMapItem(signId: 1, longitude: 105.6,
          latitude: 21.6, count: 1),
      ]);
    final merged = SignApprovedOverlay.merge(source, [
      patch(-2, 105.8, 21.8),
      patch(-3, 105.9, 21.9, deleted: true),
      patch(-4, 108, 24),
    ], viewport, filter);
    expect(merged.total, 2);
    expect(merged.items.map((v) => v.signId), [1, -2]);
  });

  test('dense approved overlay reclusters without losing aggregate counts',
      () {
    final source = SignViewportResult(total: 320,
      items: List.generate(320, (i) => SignMapItem(
        signId: i, longitude: 105.2 + i * 0.00001,
        latitude: 21.2 + i * 0.00001, count: 1,
      )),
    );
    final merged = SignApprovedOverlay.merge(source, [
      patch(-1, 105.25, 21.25),
      patch(-2, 105.3, 21.3),
    ], viewport, filter);
    expect(merged.total, 322);
    expect(merged.items.length, lessThanOrEqualTo(320));
    expect(merged.items.fold<int>(0, (x, y) => x + y.count), 322);
    expect(merged.items.any((x) => x.isCluster), true);
  });

  test('approved speed filter accepts only code 1 and positive raw value',
      () {
    final result = SignApprovedOverlay.merge(SignViewportResult.empty, [
      patch(-1, 105.2, 21.2, code: 1, raw: 80),
      patch(-2, 105.3, 21.3, code: 4, raw: 80),
      patch(-3, 105.4, 21.4, code: 1, raw: 0),
    ], viewport,
      const TrafficSignFilter(enabled: true, speedOnly: true));
    expect(result.total, 1);
    expect(result.items.single.signId, -1);
  });
}
