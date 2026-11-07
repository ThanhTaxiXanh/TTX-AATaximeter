import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/memory_usage_probe.dart';

void main() {
  test('empty sample window has defined zero readings', () {
    final w = RssSampleWindow(capacity: 3);
    expect(w.count, 0);
    expect(w.lastBytes, 0);
    expect(w.minimumBytes, 0);
    expect(w.maximumBytes, 0);
  });

  test('bounded RSS window discards old samples, never grows', () {
    final w = RssSampleWindow(capacity: 3);
    w.record(10);
    w.record(30);
    w.record(20);
    expect(w.count, 3);
    expect(w.lastBytes, 20);
    expect(w.minimumBytes, 10);
    expect(w.maximumBytes, 30);
    w.record(25);
    expect(w.count, 3);
    expect(w.minimumBytes, 20);
    expect(w.maximumBytes, 30);
    expect(w.lastBytes, 25);
  });

  test('invalid measurements are ignored and reset clears window', () {
    final w = RssSampleWindow(capacity: 2);
    w.record(15);
    w.record(-100);
    expect(w.count, 1);
    expect(w.lastBytes, 15);
    w.clear();
    expect(w.count, 0);
    w.record(22);
    expect(w.maximumBytes, 22);
    expect(w.minimumBytes, 22);
  });
}
