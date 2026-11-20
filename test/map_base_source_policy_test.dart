import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/map_base_source_policy.dart';

void main() {
  test('2D map source cycles without unsupported offline tile download', () {
    var source = Map2DBaseSource.raster;
    expect(source.fetchesRasterTiles, isTrue);
    expect(source.usesVectorStyle, isFalse);
    source = source.next;
    expect(source, Map2DBaseSource.vector);
    expect(source.usesVectorStyle, isTrue);
    source = source.next;
    expect(source, Map2DBaseSource.offlineSigns);
    expect(source.referenceOnly, isTrue);
    expect(source.fetchesRasterTiles, isFalse);
    expect(source.usesVectorStyle, isFalse);
    expect(source.sourceDescription, contains('không có bản đồ nền'));
    expect(source.next, Map2DBaseSource.raster);
  });

  test('offline source is never described as a road basemap', () {
    const source = Map2DBaseSource.offlineSigns;
    expect(source.sourceDescription, contains('Chỉ GPS và biển báo'));
    expect(source.sourceDescription, isNot(contains('bản đồ ngoại tuyến')));
  });
  test('auto-recovery fires exactly once for the current failed style', () {
    final gate = VectorStyleRecoveryGate();
    expect(gate.pending, false);
    final first = gate.arm();
    expect(gate.pending, true);
    expect(gate.consumeTimeout(first), true);
    expect(gate.pending, false);
    expect(gate.consumeTimeout(first), false);
  });

  test('protected style success prevents offline fallback on stale timer', () {
    final gate = VectorStyleRecoveryGate();
    final started = gate.arm();
    gate.cancel();
    expect(gate.pending, false);
    expect(gate.consumeTimeout(started), false);
  });

  test('manual source switch or new style invalidates prior timeout', () {
    final gate = VectorStyleRecoveryGate();
    final stale = gate.arm();
    final current = gate.arm();
    expect(gate.consumeTimeout(stale), false);
    expect(gate.consumeTimeout(current), true);
    final afterManualSwitch = gate.arm();
    gate.cancel();
    expect(gate.consumeTimeout(afterManualSwitch), false);
  });

}
