import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/trip_session_snapshot.dart';

void main() {
  final t0 = DateTime(2026, 11, 4, 9, 0, 0);
  final t1 = t0.add(const Duration(minutes: 5));
  final muchLater = t1.add(const Duration(hours: 3));

  test('crash restore preserves price, km, waiting, toll and original tariff', () {
    final m = TaximeterEngine(tariff: TariffConfig.demo());
    m.start(at: t0);
    m.distanceMeters = 15333;
    m.addToll(35000);
    m.tick(t1);
    final previousFare = m.totalFare;
    final saved = TripSessionSnapshot.fromEngine(m,
      pickup: 'Ga Hà Nội', dropoff: 'Sân bay').encode();
    final restoredData = TripSessionSnapshot.decode(saved);
    final recovered = restoredData.restore(at: muchLater);
    expect(recovered.requiresManualResume, true);
    expect(recovered.status, MeterStatus.paused);
    expect(restoredData.pickup, 'Ga Hà Nội');
    expect(restoredData.dropoff, 'Sân bay');
    expect(recovered.distanceKm, 15.333);
    expect(recovered.totalFare, previousFare);
    final elapsed = recovered.elapsedSeconds;
    final waiting = recovered.waitingSeconds;
    recovered.tick(muchLater.add(const Duration(minutes: 20)));
    expect(recovered.elapsedSeconds, elapsed);
    expect(recovered.waitingSeconds, waiting);
    expect(recovered.totalFare, previousFare);
    recovered.resume(at: muchLater.add(const Duration(minutes: 20)));
    expect(recovered.requiresManualResume, false);
    recovered.speedKmh = 50;
    recovered.tick(muchLater.add(const Duration(minutes: 21)));
    expect(recovered.elapsedSeconds, elapsed + 60);
    expect(recovered.waitingSeconds, waiting);
  });

  test('background interruption is not the same as manual waiting pause', () {
    final meter = TaximeterEngine(tariff: TariffConfig.demo());
    meter.start(at: t0);
    meter.suspendForInterruption(at: t1);
    final waiting = meter.waitingSeconds;
    meter.tick(muchLater);
    expect(meter.waitingSeconds, waiting);
    meter.finish(at: muchLater.add(const Duration(hours: 1)));
    expect(meter.waitingSeconds, waiting);
  });

  test('corrupted / inactive snapshot cannot be resumed', () {
    expect(() => TripSessionSnapshot.decode('{}'), throwsFormatException);
    final m = TaximeterEngine(tariff: TariffConfig.demo());
    expect(() => m.exportSnapshot(), throwsStateError);
    m.start(at: t0);
    final s = m.exportSnapshot();
    s['waitingSeconds'] = 1000;
    s['elapsedSeconds'] = 10;
    expect(() => TaximeterEngine.fromSnapshot(
      tariff: m.tariff, snapshot: s, recoveredAt: muchLater),
      throwsFormatException);
  });
}
