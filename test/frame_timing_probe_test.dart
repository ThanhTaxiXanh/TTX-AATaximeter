import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/frame_timing_probe.dart';

void main() {
  test('p95 is zero when there are no frames', () {
    expect(FrameTimingProbe.percentile95(const []), 0);
  });

  test('p95 uses nearest-rank without mutating the original samples', () {
    final original = <double>[3, 9, 1, 5, 7, 2, 6, 4, 8, 10];
    expect(FrameTimingProbe.percentile95(original), 10);
    expect(original, [3, 9, 1, 5, 7, 2, 6, 4, 8, 10]);
    final range = List<double>.generate(100, (i) => (i + 1).toDouble());
    expect(FrameTimingProbe.percentile95(range), 95);
  });

  test('p95 handles one frame and repeated timings', () {
    expect(FrameTimingProbe.percentile95([16.7]), 16.7);
    expect(FrameTimingProbe.percentile95([5, 5, 5, 5]), 5);
  });
}
