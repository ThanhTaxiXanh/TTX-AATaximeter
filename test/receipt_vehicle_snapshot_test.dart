import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';
import 'package:ttx_aataximeter/src/data/trip_session_snapshot.dart';
import 'package:ttx_aataximeter/src/domain/fare_breakdown.dart';

void main() {
  final tariff = TariffConfig.demo().copyWith(
    name: 'Tài xế nhập: Hương Giang',
    baseFare: 30000, baseDistanceKm: 1.5,
    fareTiers: const [
      FareTier(upToKm: 30, ratePerKm: 15000),
      FareTier(upToKm: null, ratePerKm: 12000),
    ],
  );
  final start = DateTime(2026, 11, 4, 7);

  test('invoice preserves vehicle/company/tariff when selected profile changes', () {
    final m = TaximeterEngine(tariff: tariff);
    m.start(at: start);
    m.distanceMeters = 35000;
    final record = TripRecord.fromReceipt(
      m.finish(at: start.add(const Duration(minutes: 45))),
      pickup: 'Bến xe', dropoff: 'Sân bay',
      vehicleType: 'Xe 5 chỗ', vehiclePlate: '98G-001.07',
      vehicleBrand: 'VinFast',
      fareProfileName: 'Taxi Hương Giang', tariffSnapshot: tariff,
    );
    final decoded = TripRecord.decode(record.encode());
    expect(decoded.vehiclePlate, '98G-001.07');
    expect(decoded.vehicleType, 'Xe 5 chỗ');
    expect(decoded.vehicleBrand, 'VinFast');
    expect(decoded.fareProfileName, 'Taxi Hương Giang');
    expect(decoded.tariffSnapshot!.baseFare, 30000);
    final breakdown = calculateFareBreakdown(
        tariff: decoded.tariffSnapshot!,
        distanceKm: decoded.receipt.distanceKm, tripStarted: true);
    expect(breakdown[1].capacityKm, 28.5);
    expect(breakdown[2].traveledKm, 5);
    expect(breakdown.fold<double>(0, (v, r) => v + r.amount),
        decoded.receipt.baseFare + decoded.receipt.distanceFare);
    final paid = decoded.copyWith(paymentMethod: PaymentMethod.card);
    expect(paid.vehiclePlate, decoded.vehiclePlate);
    expect(paid.vehicleBrand, 'VinFast');
    expect(paid.tariffSnapshot!.fareTiers!.length, 2);
  });

  test('session recovery freezes vehicle metadata before receipt', () {
    final m = TaximeterEngine(tariff: tariff);
    m.start(at: start);
    final s = TripSessionSnapshot.fromEngine(m,
      pickup: 'A', dropoff: 'B', vehicleType: 'Xe 7 Chỗ',
      vehiclePlate: '99A-123.45', vehicleBrand: 'Toyota',
      fareProfileName: 'Cấu hình B',
    );
    final restored = TripSessionSnapshot.decode(s.encode());
    expect(restored.vehicleType, 'Xe 7 Chỗ');
    expect(restored.vehiclePlate, '99A-123.45');
    expect(restored.vehicleBrand, 'Toyota');
    expect(restored.fareProfileName, 'Cấu hình B');
    expect(restored.restore(at: start.add(const Duration(hours: 2)))
        .requiresManualResume, isTrue);
  });

  test('legacy receipt without vehicle fields can still be decoded', () {
    final m = TaximeterEngine(tariff: tariff);
    m.start(at: start);
    final old = TripRecord.fromReceipt(m.finish(
      at: start.add(const Duration(minutes: 3))));
    final restored = TripRecord.decode(old.encode());
    expect(restored.vehiclePlate, '');
    expect(restored.vehicleBrand, '');
    expect(restored.tariffSnapshot, isNull);
  });
}
