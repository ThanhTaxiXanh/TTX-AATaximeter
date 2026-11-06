import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ttx_aataximeter/src/data/backup_logo_asset.dart';
import 'package:ttx_aataximeter/src/data/backup_settings_importer.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';
import 'package:ttx_aataximeter/src/payment/vietqr.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('settings import plan never picks an already present configuration',
      () {
    final archive = SettingsBackupBundle.fromValues({
      DashboardPreferences.storageKey:
        const DashboardPreferences(darkMap: true).encode(),
      'ttx_vietqr_bank_book_v1': const BankBook().encode(),
    });
    final device = SettingsBackupBundle.fromValues({
      DashboardPreferences.storageKey:
        const DashboardPreferences(darkMap: false).encode(),
    });
    final plan = SettingsImportPlan.compare(
      archive: archive, device: device);
    expect(plan.missing.keys, contains('ttx_vietqr_bank_book_v1'));
    expect(plan.missing.keys, isNot(contains(
      DashboardPreferences.storageKey)));
    expect(plan.skippedExisting, 1);
  });

  test('imports missing bank book and portable logo, allows re-export',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = SharedPreferencesAsync();
    final root = await Directory.systemTemp.createTemp('ttx-settings-import-');
    try {
      const oldPath = '/invalid/other-phone/center.png';
      final sourceBook = const BankBook(centerLogoPath: oldPath).encode();
      final archive = SettingsBackupBundle.fromValues({
        'ttx_vietqr_bank_book_v1': sourceBook,
        DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: true).encode(),
      });
      final logo = BackupLogoAsset(
        slot: 'center', extension: 'png',
        bytes: Uint8List.fromList(
          const [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]));
      final first = await BackupSettingsImporter.importMissing(
        preferences: preferences,
        archive: archive, logos: [logo],
        supportDirectory: root);
      expect(first.addedKeys, 2);
      expect(first.restoredLogos, 1);

      final imported = BankBook.decode(
        (await preferences.getString('ttx_vietqr_bank_book_v1'))!);
      expect(imported.centerLogoPath, isNot(oldPath));
      expect(await File(imported.centerLogoPath!).exists(), true);
      final recaptured = await BackupLogoCapture.fromBankBook(
        bankBook: imported, appSupportDirectory: root);
      expect(recaptured.single.bytes, logo.bytes);
      final second = await BackupSettingsImporter.importMissing(
        preferences: preferences,
        archive: archive, logos: [logo],
        supportDirectory: root);
      expect(second.addedKeys, 0);
      expect(second.skippedExistingKeys, 2);
      expect(second.restoredLogos, 0);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('existing bank account remains selected while new archived account '
      'and missing footer logo are merged safely', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = SharedPreferencesAsync();
    final current = const DashboardPreferences(darkMap: false).encode();
    await preferences.setString(DashboardPreferences.storageKey, current);
    final oldBook = BankBook(
      accounts: [
        SavedBankAccount(
          id: 'device-account',
          bankName: 'Existing Bank',
          account: const VietQrAccount(
            bankBin: '970407', accountNumber: '12345',
            accountName: 'EXISTING PAYEE')),
      ],
      defaultId: 'device-account',
      centerLogoPath: '/existing/device-center.png',
    );
    await preferences.setString(
      'ttx_vietqr_bank_book_v1', oldBook.encode());
    final archived = BankBook(
      accounts: [
        SavedBankAccount(
          id: 'archived-account',
          bankName: 'Archive Bank',
          account: const VietQrAccount(
            bankBin: '970407', accountNumber: '67890',
            accountName: 'ARCHIVE PAYEE')),
      ],
      defaultId: 'archived-account',
    );
    final root = await Directory.systemTemp.createTemp('ttx-keep-existing-');
    try {
      final saved = SettingsBackupBundle.fromValues({
        'ttx_vietqr_bank_book_v1': archived.encode(),
        DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: true).encode(),
      });
      final footer = BackupLogoAsset(
        slot: 'footer', extension: 'png',
        bytes: Uint8List.fromList(
          const [137, 80, 78, 71, 13, 10, 26, 10, 5]));
      final result = await BackupSettingsImporter.importMissing(
        preferences: preferences,
        archive: saved,
        logos: [footer],
        supportDirectory: root);
      expect(result.addedKeys, 0);
      expect(result.addedBankAccounts, 1);
      expect(result.updatedBankBook, true);
      expect(result.restoredLogos, 1);
      expect(await preferences.getString(DashboardPreferences.storageKey),
        current);
      final merged = BankBook.decode(
        (await preferences.getString('ttx_vietqr_bank_book_v1'))!);
      expect(merged.accounts, hasLength(2));
      expect(merged.accounts.first.id, 'device-account');
      expect(merged.defaultId, 'device-account');
      expect(merged.centerLogoPath, oldBook.centerLogoPath);
      expect(await File(merged.footerLogoPath!).exists(), true);
      final repeated = await BackupSettingsImporter.importMissing(
        preferences: preferences,
        archive: saved,
        logos: [footer],
        supportDirectory: root);
      expect(repeated.addedBankAccounts, 0);
      expect(repeated.restoredLogos, 0);
      expect(repeated.updatedBankBook, false);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('existing EMPTY bank book no longer prevents restoring VietQR',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'ttx_vietqr_bank_book_v1', const BankBook().encode());
    final archiveBook = BankBook(
      accounts: [
        SavedBankAccount(
          id: 'backup-1', bankName: 'Saved Bank',
          account: const VietQrAccount(
            bankBin: '970407', accountNumber: '123456789',
            accountName: 'SAVED PAYEE')),
      ],
      defaultId: 'backup-1',
    );
    final archive = SettingsBackupBundle.fromValues({
      'ttx_vietqr_bank_book_v1': archiveBook.encode(),
    });
    final center = BackupLogoAsset(
      slot: 'center', extension: 'png',
      bytes: Uint8List.fromList(
        const [137, 80, 78, 71, 13, 10, 26, 10, 5]));
    final footer = BackupLogoAsset(
      slot: 'footer', extension: 'png',
      bytes: Uint8List.fromList(
        const [137, 80, 78, 71, 13, 10, 26, 10, 6]));
    final root = await Directory.systemTemp.createTemp('ttx-empty-bank-');
    try {
      final result = await BackupSettingsImporter.importMissing(
        preferences: preferences, archive: archive,
        logos: [center, footer], supportDirectory: root);
      expect(result.addedKeys, 0); // key existed; entries are new.
      expect(result.addedBankAccounts, 1);
      expect(result.restoredLogos, 2);
      final stored = BankBook.decode(
        (await preferences.getString('ttx_vietqr_bank_book_v1'))!);
      expect(stored.accounts, hasLength(1));
      expect(stored.selected?.id, 'backup-1');
      expect(await File(stored.centerLogoPath!).exists(), isTrue);
      expect(await File(stored.footerLogoPath!).exists(), isTrue);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('legacy bank book path is cleared if archive has no logo bytes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = SharedPreferencesAsync();
    final root = await Directory.systemTemp.createTemp('ttx-legacy-path-');
    try {
      final archived = SettingsBackupBundle.fromValues({
        'ttx_vietqr_bank_book_v1':
          const BankBook(footerLogoPath: '/old/footer.jpg').encode(),
      });
      await BackupSettingsImporter.importMissing(
        preferences: preferences,
        archive: archived, logos: const [],
        supportDirectory: root);
      final restored = BankBook.decode(
        (await preferences.getString('ttx_vietqr_bank_book_v1'))!);
      expect(restored.footerLogoPath, isNull);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
