import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/vehicle_registration.dart';

void main() {
  test('5/7-seat vehicle registration and brand persist', () {
    for (final category in VehicleCategory.selectable) {
      final registration = VehicleRegistration(
        category: category, plate: ' 98g-001.07 ', brand: ' VinFast ');
      final restored = VehicleRegistration.decode(registration.encode());
      expect(restored.category, category);
      expect(restored.plate, '98G-001.07');
      expect(restored.brand, 'VinFast');
      expect(restored.needsDetails, false);
    }
    expect(VehicleCategory.selectable.length, 2);
  });

  test('legacy four-seater maps to five seats; plate is not erased', () {
    final r = VehicleRegistration.decode(
      '{"schema":1,"category":"fourSeats","plate":"98G-001.07"}');
    expect(r.category, VehicleCategory.fiveSeats);
    expect(r.plate, '98G-001.07');
    expect(r.brand, '');
    expect(r.needsDetails, true);
  });

  test('legacy sixteen-seat registration requires driver re-selection', () {
    final r = VehicleRegistration.decode(
      '{"schema":1,"category":"sixteenSeats","plate":"99A-123.45"}');
    expect(r.category, VehicleCategory.legacySixteenSeats);
    expect(r.needsDetails, true);
    expect(VehicleCategory.selectable, isNot(contains(r.category)));
  });

  test('invalid plate, excessive brand, unsupported schema rejected', () {
    expect(() => VehicleRegistration(
      category: VehicleCategory.fiveSeats, plate: '', brand: 'VinFast'),
      throwsArgumentError);
    expect(() => VehicleRegistration(
      category: VehicleCategory.sevenSeats,
      plate: '123@987', brand: 'Toyota'), throwsArgumentError);
    expect(() => VehicleRegistration(
      category: VehicleCategory.sevenSeats,
      plate: '99A-123.45', brand: 'A' * 61), throwsArgumentError);
    expect(() => VehicleRegistration.decode(
      '{"schema":3,"category":"fiveSeats","plate":"99A-123.45"}'),
      throwsFormatException);
  });
}
