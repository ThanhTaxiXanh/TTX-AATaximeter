import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/map_style_epoch.dart';

void main() {
  test('style reload invalidates previous asynchronous results', () {
    final gate = MapStyleEpoch();
    final first = gate.begin();
    expect(gate.isCurrent(first), isTrue);
    gate.invalidate();
    expect(gate.isCurrent(first), isFalse);
    final next = gate.begin();
    expect(gate.isCurrent(next), isTrue);
    expect(gate.isCurrent(first), isFalse);
  });

  test('concurrent style loads only permit the newest completion', () {
    final gate = MapStyleEpoch();
    final first = gate.begin();
    final second = gate.begin();
    expect(gate.isCurrent(first), isFalse);
    expect(gate.isCurrent(second), isTrue);
    gate.dispose();
    expect(gate.isCurrent(second), isFalse);
  });

  test('map disposal prevents new native style work', () {
    final gate = MapStyleEpoch();
    final running = gate.begin();
    gate.dispose();
    expect(gate.isCurrent(running), isFalse);
    gate.invalidate();
    expect(gate.isCurrent(running), isFalse);
    expect(gate.begin, throwsStateError);
  });

  test('epoch captured during async operation cannot become active again', () {
    final gate = MapStyleEpoch();
    final stale = gate.begin();
    for (var i = 0; i < 20; i++) {
      gate.invalidate();
      expect(gate.isCurrent(stale), isFalse);
      final current = gate.begin();
      expect(gate.isCurrent(current), isTrue);
      expect(current, greaterThan(stale));
    }
  });
}
