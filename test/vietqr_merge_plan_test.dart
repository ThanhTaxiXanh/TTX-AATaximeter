import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/data/backup_logo_asset.dart';
import 'package:ttx_aataximeter/src/data/vietqr_merge_plan.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';
import 'package:ttx_aataximeter/src/payment/vietqr.dart';

SavedBankAccount account(String id, String number) => SavedBankAccount(
  id: id,
  bankName: 'Test Bank',
  account: VietQrAccount(
    bankBin: '970407', accountNumber: number, accountName: 'TEST PAYEE'),
);

void main() {
  test('empty existing bank book accepts archived account and two logos',
      () {
    final archived = BankBook(
      accounts: [account('from-archive', '1234567')],
      defaultId: 'from-archive');
    final result = VietQrMergePlan.compare(
      device: const BankBook(), archive: archived,
      logos: [
        BackupLogoAsset(
          slot: 'center', extension: 'png',
          bytes: Uint8List.fromList(
            const [137, 80, 78, 71, 13, 10, 26, 10])),
        BackupLogoAsset(
          slot: 'footer', extension: 'png',
          bytes: Uint8List.fromList(
            const [137, 80, 78, 71, 13, 10, 26, 10, 1])),
      ],
    );
    expect(result.accountsToAdd, 1);
    expect(result.logoSlotsToAdd, containsAll(['center', 'footer']));
    expect(result.book.selected?.id, 'from-archive');
  });

  test('existing account and default are retained, duplicate is skipped',
      () {
    final current = BankBook(
      accounts: [account('device', '10000')],
      defaultId: 'device', centerLogoPath: '/existing/logo.png');
    final incoming = BankBook(
      accounts: [
        account('different-id', '10000'),
        account('second', '20000'),
      ],
      defaultId: 'second');
    final plan = VietQrMergePlan.compare(
      device: current, archive: incoming,
      logos: [
        BackupLogoAsset(
          slot: 'center', extension: 'png',
          bytes: Uint8List.fromList(
            const [137, 80, 78, 71, 13, 10, 26, 10])),
      ],
    );
    expect(plan.accountsToAdd, 1);
    expect(plan.logoSlotsToAdd, isEmpty);
    expect(plan.book.defaultId, 'device');
    expect(plan.book.accounts, hasLength(2));
    expect(plan.book.accounts.first.id, 'device');
    expect(plan.book.centerLogoPath, '/existing/logo.png');
  });

  test('conflicting archive ID is renamed, never replaces device account',
      () {
    final current = BankBook(
      accounts: [account('same-id', '10000')],
      defaultId: 'same-id');
    final incoming = BankBook(
      accounts: [account('same-id', '20000')],
      defaultId: 'same-id');
    final merged = VietQrMergePlan.compare(
      device: current, archive: incoming, logos: const []);
    expect(merged.accountsToAdd, 1);
    expect(merged.book.accounts, hasLength(2));
    expect(merged.book.accounts.first.id, 'same-id');
    expect(merged.book.accounts.last.id, isNot('same-id'));
    expect(merged.book.defaultId, 'same-id');
    final repeat = VietQrMergePlan.compare(
      device: merged.book, archive: incoming, logos: const []);
    expect(repeat.accountsToAdd, 0);
    expect(repeat.hasChanges, false);
  });
}
