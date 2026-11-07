import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/payment/bank_catalog.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';
import 'package:ttx_aataximeter/src/payment/vietqr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline VietQR JSON contains exactly 76 unique BIN entries', () async {
    final raw = await rootBundle.loadString('assets/data/vietqr_banks.json');
    final catalog = BankCatalog.fromJson(raw);
    expect(catalog.banks.length, 76);
    expect(catalog.banks.map((e) => e.bin).toSet().length, 76);
    expect(catalog.search('Techcombank').first.bin, '970407');
    expect(catalog.search('Vietcombank').first.bin, '970436');
    expect(catalog.search('970422').first.shortName, 'MBBank');
  });

  test('bank selection is stable across JSON and keeps local brand paths', () {
    const first = VietQrAccount(bankBin: '970407',
      accountNumber: '1234567890', accountName: 'OWNER ONE');
    const second = VietQrAccount(bankBin: '970436',
      accountNumber: '9876543210', accountName: 'OWNER TWO');
    final book = BankBook(
      accounts: const [
        SavedBankAccount(id: 'a', bankName: 'Techcombank', account: first),
        SavedBankAccount(id: 'b', bankName: 'Vietcombank', account: second),
      ],
      defaultId: 'b',
      centerLogoPath: '/logo/center.png',
      footerLogoPath: '/logo/footer.svg',
    );
    final restored = BankBook.decode(book.encode());
    expect(restored.selected!.account.bankBin, '970436');
    expect(restored.centerLogoPath, '/logo/center.png');
    expect(restored.footerLogoPath, '/logo/footer.svg');
    expect(restored.copyWith(defaultId: 'a').selected!.bankName, 'Techcombank');
    expect(restored.copyWith(removeFooterLogo: true).footerLogoPath, isNull);
    expect(BankBook.migrateLegacy(first).selected!.account.bankBin, '970407');
  });

  test('VietQR local payload has BIN, account, amount and CRC16', () {
    const account = VietQrAccount(bankBin: '970407',
      accountNumber: '1234567890', accountName: 'OWNER ONE');
    final payload = account.emvPayload(
        amountVnd: 150000, memo: 'TTX TAXI');
    expect(payload.startsWith('000201'), isTrue);
    expect(payload.contains('970407'), isTrue);
    expect(payload.contains('1234567890'), isTrue);
    expect(payload.contains('150000'), isTrue);
    expect(RegExp(r'6304[A-Fa-f0-9]{4}$').hasMatch(payload), isTrue);
    expect(account.emvPayload(
        amountVnd: 0, memo: 'TTX TAXI').startsWith('000201'), isTrue);
  });
}
