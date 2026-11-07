import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';
import 'package:ttx_aataximeter/src/payment/bank_catalog.dart';
import 'package:ttx_aataximeter/src/ui/bank_accounts_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = BankCatalog.fromJson('''
{
  "code": "00",
  "data": [
    {"bin":"970407","code":"TCB","name":"Ngân hàng Techcombank",
      "shortName":"Techcombank","transferSupported":1},
    {"bin":"970436","code":"VCB","name":"Ngân hàng Vietcombank",
      "shortName":"Vietcombank","transferSupported":1},
    {"bin":"970422","code":"MB","name":"Ngân hàng MBBank",
      "shortName":"MBBank","transferSupported":1},
    {"bin":"970415","code":"ICB","name":"Ngân hàng VietinBank",
      "shortName":"VietinBank","transferSupported":1},
    {"bin":"970418","code":"BIDV","name":"Ngân hàng BIDV",
      "shortName":"BIDV","transferSupported":1},
    {"bin":"970405","code":"VBA","name":"Ngân hàng Agribank",
      "shortName":"Agribank","transferSupported":1},
    {"bin":"970448","code":"OCB","name":"Ngân hàng OCB",
      "shortName":"OCB","transferSupported":1},
    {"bin":"970416","code":"ACB","name":"Ngân hàng ACB",
      "shortName":"ACB","transferSupported":1},
    {"bin":"970432","code":"VPB","name":"Ngân hàng VPBank",
      "shortName":"VPBank","transferSupported":1},
    {"bin":"970423","code":"TPB","name":"Ngân hàng TPBank",
      "shortName":"TPBank","transferSupported":1}
  ]
}
''');

  testWidgets('search and select bank repeatedly without third modal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    BankBook? saved;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: Builder(
        builder: (ctx) => FilledButton(
          onPressed: () async {
            saved = await showDialog<BankBook>(
              context: ctx,
              builder: (_) => BankAccountsDialog(
                initial: const BankBook(), catalog: catalog,
              ),
            );
          },
          child: const Text('Mở quản lý'),
        ),
      )),
    ));

    for (var cycle = 0; cycle < 2; cycle++) {
      await tester.tap(find.text('Mở quản lý'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm tài khoản ngân hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ngân hàng theo tên'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bank-search-field')), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.enterText(
        find.byKey(const Key('bank-search-field')), 'Tech');
      await tester.pumpAndSettle();
      expect(find.text('Techcombank'), findsOneWidget);
      await tester.tap(find.text('Techcombank'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bank-inline-results')), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Số tài khoản'),
        '1234567890');
      await tester.enterText(
        find.byKey(const Key('bank-account-owner-field')),
        'nguyễn văn a');
      expect(
        tester.widget<TextField>(
          find.byKey(const Key('bank-account-owner-field')))
          .controller!.text,
        'NGUYỄN VĂN A',
      );
      await tester.ensureVisible(find.text('Lưu'));
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Techcombank'), findsOneWidget);
      await tester.tap(find.text('LƯU TÀI KHOẢN & LOGO'));
      await tester.pumpAndSettle();
      expect(saved?.selected?.account.bankBin, '970407');
      expect(saved?.selected?.account.accountName, 'NGUYỄN VĂN A');
      expect(find.text('Số tài khoản / Alias'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cancel search while keyboard is active without assertion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(
        builder: (ctx) => FilledButton(
          onPressed: () => showDialog<void>(
            context: ctx,
            builder: (_) => BankAccountsDialog(
              initial: const BankBook(), catalog: catalog,
            ),
          ),
          child: const Text('Mở'),
        ),
      )),
    ));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm tài khoản ngân hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn ngân hàng theo tên'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('bank-search-field')), 'Viet');
    await tester.pump();
    await tester.tap(find.text('Chọn ngân hàng theo tên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
