import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/raster_tile_failover.dart';

void main() {
  test('one failed raster tile does not immediately switch providers', () {
    final gate = RasterTileFailover();
    expect(gate.useVectorFallback, false);
    expect(gate.recordFailure(), false);
    expect(gate.failures, 1);
    expect(gate.recordFailure(), false);
    expect(gate.useVectorFallback, false);
  });

  test('three failures switch to vector once, subsequent errors are ignored', () {
    final gate = RasterTileFailover();
    expect(gate.recordFailure(), false);
    expect(gate.recordFailure(), false);
    expect(gate.recordFailure(), true);
    expect(gate.useVectorFallback, true);
    expect(gate.recordFailure(), false);
    expect(gate.failures, 3);
  });

  test('manual retry re-enables the lightweight OSM tile layer', () {
    final gate = RasterTileFailover();
    for (var i = 0; i < 3; i++) { gate.recordFailure(); }
    gate.reset();
    expect(gate.failures, 0);
    expect(gate.useVectorFallback, false);
    expect(gate.recordFailure(), false);
  });
}
