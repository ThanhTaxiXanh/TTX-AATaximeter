import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/road_query_gate.dart';

void main() {
  final start = DateTime.utc(2026, 11, 7, 1);
  bool query(RoadQueryGate gate, int seconds, {
    double lat = 21, double lon = 105, bool force = false,
  }) => gate.shouldQuery(
    now: start.add(Duration(seconds: seconds)),
    latitude: lat, longitude: lon, force: force,
  );

  test('stationary named roads are not re-queried every six seconds', () {
    final gate = RoadQueryGate();
    expect(query(gate, 0), isTrue);
    gate.reportName('Đường Trần Phú');
    expect(query(gate, 5), isFalse);
    expect(query(gate, 6), isFalse);
    expect(query(gate, 20), isFalse);
    expect(query(gate, 44), isFalse);
    expect(query(gate, 45), isTrue);
  });

  test('movement gets fresh street name after normal cooldown', () {
    final gate = RoadQueryGate();
    expect(query(gate, 0), isTrue);
    gate.reportName('Đường cũ');
    // About 22 m north at 21 degrees latitude.
    expect(query(gate, 3, lat: 21.0002), isFalse);
    expect(query(gate, 6, lat: 21.0002), isTrue);
    gate.reportName('Đường mới');
    expect(query(gate, 12, lat: 21.00021), isFalse);
    expect(query(gate, 18, lat: 21.0004), isTrue);
  });

  test('unresolved names are retried earlier to handle unloaded tiles', () {
    final gate = RoadQueryGate();
    expect(query(gate, 0), isTrue);
    gate.reportName(null);
    expect(query(gate, 6), isFalse);
    expect(query(gate, 14), isFalse);
    expect(query(gate, 15), isTrue);
    gate.reportName('');
    expect(query(gate, 30), isTrue);
  });

  test('style changes and explicit force allow immediate refresh', () {
    final gate = RoadQueryGate();
    expect(query(gate, 0), isTrue);
    gate.reportName('Đường cũ');
    expect(query(gate, 1, force: true), isTrue);
    expect(query(gate, 2), isFalse);
    gate.reset();
    expect(query(gate, 2), isTrue);
  });

  test('invalid coordinates never become a query baseline', () {
    final gate = RoadQueryGate();
    expect(query(gate, 0, lat: double.nan), isFalse);
    expect(query(gate, 1, lat: 91), isFalse);
    expect(query(gate, 2), isTrue);
  });

  test('a system clock reversal does not permanently disable queries', () {
    final gate = RoadQueryGate();
    expect(query(gate, 20), isTrue);
    gate.reportName('QL1A');
    expect(query(gate, 10), isTrue);
  });
}
