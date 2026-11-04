import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/vehicle_registration.dart';

void main() {
  test('vehicle data is normalized and round-trips', () {
    final v = VehicleRegistration(
      category: VehicleCategory.fourSeats,
      plate: ' 98g-001.07 ',
    );
    expect(v.plate, '98G-001.07');
    final read = VehicleRegistration.decode(v.encode());
    expect(read.plate, v.plate);
    expect(read.category, VehicleCategory.fourSeats);
  });

  test('all seat selections persist', () {
    for (final category in VehicleCategory.values) {
      final reg = VehicleRegistration(
          category: category, plate: '99A-123.45');
      expect(VehicleRegistration.decode(reg.encode()).category, category);
    }
  });

  test('missing plates and unsupported characters are rejected', () {
    expect(() => VehicleRegistration(
      category: VehicleCategory.fourSeats, plate: ''),
      throwsArgumentError);
    expect(() => VehicleRegistration(
      category: VehicleCategory.sevenSeats, plate: '123@987'),
      throwsArgumentError);
    expect(() => VehicleRegistration.decode(
      '{"schema":2,"category":"fourSeats","plate":"99A-123.45"}'),
      throwsFormatException);
  });
}
