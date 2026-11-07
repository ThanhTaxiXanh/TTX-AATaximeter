import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';
import 'package:ttx_aataximeter/src/payment/vietqr.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';
import 'package:ttx_aataximeter/src/ui/trip_receipt_dialog.dart';

void main() {
  testWidgets('receipt has BOT row, cash/transfer only and inline QR',
      (tester) async {
    final at = DateTime(2026, 11, 4);
    final r = TripRecord.fromReceipt(TripReceipt(
      startedAt: at, endedAt: at.add(const Duration(minutes: 3)),
      distanceKm: 0.2, durationSeconds: 180, waitingSeconds: 0,
      baseFare: 30000, distanceFare: 0, waitingFare: 0,
      tollFee: 0, surcharge: 0, discount: 0,
      totalFare: 30000, isFlatFare: false,
    ));
    final book = BankBook(
      accounts: const [
        SavedBankAccount(
          id: 'b', bankName: 'Techcombank',
          account: VietQrAccount(
            bankBin: '970407', accountNumber: '1234567890',
            accountName: 'OWNER ONE',
          ),
        ),
      ],
      defaultId: 'b',
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: TripReceiptDialog(record: r, bankBook: book)),
    ));
    expect(find.text('Trạm thu phí'), findsOneWidget);
    expect(find.text('PHÍ CẦU ĐƯỜNG (BOT)'), findsNothing);
    expect(find.text('Thẻ'), findsNothing);
    expect(find.text('Sao chép nội dung biên lai'), findsNothing);
    expect(find.text('Mã VietQR chuyển khoản'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
    await tester.ensureVisible(find.text('Chuyển khoản'));
    await tester.tap(find.text('Chuyển khoản'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
