import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/vehicle_registration.dart';
import 'package:ttx_aataximeter/src/ui/vehicle_registration_dialog.dart';

void main() {
  testWidgets('vehicle picker shows 5 and 7 seats plus brand field',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    VehicleRegistration? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        FilledButton(onPressed: () async {
          saved = await showDialog<VehicleRegistration>(
            context: context,
            builder: (_) => const VehicleRegistrationDialog(),
          );
        }, child: const Text('Mở đăng ký')),
      )),
    ));
    await tester.tap(find.text('Mở đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Xe 5 chỗ'), findsOneWidget);
    expect(find.text('Xe 7 chỗ'), findsOneWidget);
    expect(find.textContaining('16 chỗ'), findsNothing);
    await tester.tap(find.text('Xe 7 chỗ'));
    await tester.enterText(find.byKey(const Key('vehicle-brand-field')),
      'VinFast');
    await tester.enterText(find.byKey(const Key('vehicle-plate-field')),
      '98G-001.07');
    await tester.ensureVisible(find.text('XÁC NHẬN'));
    await tester.tap(find.text('XÁC NHẬN'));
    await tester.pumpAndSettle();
    expect(saved?.category, VehicleCategory.sevenSeats);
    expect(saved?.brand, 'VinFast');
    expect(saved?.plate, '98G-001.07');
    expect(tester.takeException(), isNull);
  });
}
