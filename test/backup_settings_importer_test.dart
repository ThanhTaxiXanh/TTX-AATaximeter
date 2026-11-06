import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttx_aataximeter/src/data/backup_logo_asset.dart';
import 'package:ttx_aataximeter/src/data/backup_settings_importer.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';

void main() {
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

  test('import never replaces an existing bank book or map preferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = SharedPreferencesAsync();
    await preferences.setString('ttx_vietqr_bank_book_v1',
      const BankBook().encode());
    final current = const DashboardPreferences(darkMap: false).encode();
    await preferences.setString(DashboardPreferences.storageKey, current);
    final root = await Directory.systemTemp.createTemp('ttx-keep-existing-');
    try {
      final saved = SettingsBackupBundle.fromValues({
        'ttx_vietqr_bank_book_v1':
          const BankBook(centerLogoPath: '/old/center.png').encode(),
        DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: true).encode(),
      });
      final result = await BackupSettingsImporter.importMissing(
        preferences: preferences,
        archive: saved,
        logos: [
          BackupLogoAsset(
            slot: 'center', extension: 'png',
            bytes: Uint8List.fromList(
              const [137, 80, 78, 71, 13, 10, 26, 10])),
        ],
        supportDirectory: root);
      expect(result.addedKeys, 0);
      expect(result.restoredLogos, 0);
      expect((await preferences.getString(DashboardPreferences.storageKey)),
        current);
      expect(BankBook.decode(
        (await preferences.getString('ttx_vietqr_bank_book_v1'))!)
          .centerLogoPath, isNull);
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
