import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';
import 'package:ttx_aataximeter/src/payment/vietqr.dart';

void main() {
  final start = DateTime(2026, 11, 4, 8);
  final end = start.add(const Duration(minutes: 24));
  final receipt = TripReceipt(
    startedAt: start, endedAt: end,
    distanceKm: 15, durationSeconds: 1440, waitingSeconds: 0,
    baseFare: 12000, distanceFare: 210250, waitingFare: 0,
    tollFee: 0, surcharge: 0, discount: 0, totalFare: 222000,
    isFlatFare: false,
  );

  test('trip record round-trip retains receipt and payment', () {
    final original = TripRecord.fromReceipt(receipt,
      pickup: 'Bến xe', dropoff: 'Sân bay')
        .copyWith(paymentMethod: PaymentMethod.bankTransfer);
    final loaded = TripRecord.decode(original.encode());
    expect(loaded.id, original.id);
    expect(loaded.receipt.totalFare, 222000);
    expect(loaded.receipt.distanceKm, 15);
    expect(loaded.pickup, 'Bến xe');
    expect(loaded.dropoff, 'Sân bay');
    expect(loaded.paymentMethod, PaymentMethod.bankTransfer);
  });

  test('legacy flat receipt loads without payment method', () {
    final legacy = TripRecord.fromJson(receipt.toJson());
    expect(legacy.receipt.totalFare, 222000);
    expect(legacy.paymentMethod, PaymentMethod.cash);
    expect(legacy.id, contains('-'));
  });

  test('VietQR Quick Link correctly encodes amount and memo', () {
    const account = VietQrAccount(
      bankBin: '970415',
      accountNumber: '113366668888',
      accountName: 'NGUYEN VAN A',
    );
    final uri = account.quickLink(
      amountVnd: 222000, memo: 'TTX TAXI 20261104');
    expect(uri.scheme, 'https');
    expect(uri.host, 'img.vietqr.io');
    expect(uri.path, contains('970415-113366668888-compact2.png'));
    expect(uri.queryParameters['amount'], '222000');
    expect(uri.queryParameters['addInfo'], 'TTX TAXI 20261104');
  });

  test('VietQR rejects missing bank, invalid amount and memo', () {
    const missing = VietQrAccount(
      bankBin: '', accountNumber: '123', accountName: 'X');
    expect(missing.isValid, false);
    expect(() => missing.quickLink(amountVnd: 10000, memo: 'TTX'),
        throwsArgumentError);
    const valid = VietQrAccount(
      bankBin: '970415', accountNumber: '123', accountName: 'X');
    expect(() => valid.quickLink(amountVnd: 0, memo: 'TTX'),
        throwsArgumentError);
    expect(() => valid.quickLink(amountVnd: 10000, memo: 'a@b'),
        throwsArgumentError);
  });
}
