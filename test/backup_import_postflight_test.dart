import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/data/backup_import_postflight.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';
import 'package:ttx_aataximeter/src/payment/vietqr.dart';
import 'package:ttx_aataximeter/src/data/backup_logo_asset.dart';
import 'dart:typed_data';

TripBackupInspection receipts(Map<String, String> values, {
  bool active = false,
}) => TripBackupInspection(
  completedTripCount: values.length,
  completedTripDigests: Map<String, String>.unmodifiable(values),
  hasActiveTrip: active,
  activeRouteCount: 0,
);

SettingsBackupBundle preferences(Map<String, String> values) =>
    SettingsBackupBundle.fromValues(values);

void main() {
  test('verifies missing trips imported, conflicts and device data retained',
      () {
    final before = receipts({'existing': 'A', 'conflict': 'old'});
    final incoming = receipts({
      'existing': 'A', 'conflict': 'different', 'new': 'B',
    });
    final after = receipts({
      'existing': 'A', 'conflict': 'old', 'new': 'B',
    });
    final settingsBefore = preferences({
      DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: false).encode(),
    });
    final settingsIncoming = preferences({
      DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: true).encode(),
      'ttx_vietqr_bank_book_v1':
          const BankBook(centerLogoPath: '/old/center.png').encode(),
    });
    final settingsAfter = preferences({
      DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: false).encode(),
      'ttx_vietqr_bank_book_v1':
          const BankBook(centerLogoPath: '/new/center.png').encode(),
    });
    final result = BackupImportPostflight.verify(
      before: before, archive: incoming, after: after,
      beforeSettings: settingsBefore, archiveSettings: settingsIncoming,
      afterSettings: settingsAfter,
    );
    expect(result.verifiedNewTrips, 1);
    expect(result.verifiedNewSettings, 1);
    expect(result.preservedExistingTrips, 2);
    expect(result.preservedExistingSettings, 1);
  });

  test('detects a missing or altered incoming receipt', () {
    expect(() => BackupImportPostflight.verify(
      before: receipts({}),
      archive: receipts({'trip': 'sha'}),
      after: receipts({'trip': 'wrong-sha'}),
      beforeSettings: preferences({}),
      archiveSettings: preferences({}),
      afterSettings: preferences({}),
    ), throwsFormatException);
  });

  test('detects destructive modification to any pre-existing receipt', () {
    expect(() => BackupImportPostflight.verify(
      before: receipts({'existing': 'original'}),
      archive: receipts({'another': 'incoming'}),
      after: receipts({'existing': 'changed', 'another': 'incoming'}),
      beforeSettings: preferences({}),
      archiveSettings: preferences({}),
      afterSettings: preferences({}),
    ), throwsFormatException);
  });

  test('detects a missing settings key even when SQLite fully imported', () {
    expect(() => BackupImportPostflight.verify(
      before: receipts({}), archive: receipts({}), after: receipts({}),
      beforeSettings: preferences({}),
      archiveSettings: preferences({
        DashboardPreferences.storageKey:
            const DashboardPreferences(darkMap: true).encode(),
      }),
      afterSettings: preferences({}),
    ), throwsFormatException);
  });

  test('detects changes to previously configured settings', () {
    final before = preferences({
      DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: false).encode(),
    });
    final changed = preferences({
      DashboardPreferences.storageKey:
          const DashboardPreferences(darkMap: true).encode(),
    });
    expect(() => BackupImportPostflight.verify(
      before: receipts({}), archive: receipts({}), after: receipts({}),
      beforeSettings: before, archiveSettings: changed,
      afterSettings: changed,
    ), throwsFormatException);
  });

  test('an unfinished device trip blocks verification', () {
    expect(() => BackupImportPostflight.verify(
      before: receipts({}), archive: receipts({}),
      after: receipts({}, active: true),
      beforeSettings: preferences({}),
      archiveSettings: preferences({}),
      afterSettings: preferences({}),
    ), throwsStateError);
  });

  test('postflight accepts additive bank account and both recovered logos',
      () {
    final archived = BankBook(
      accounts: [
        SavedBankAccount(
          id: 'imported-1', bankName: 'Saved Bank',
          account: const VietQrAccount(
            bankBin: '970407', accountNumber: '123456',
            accountName: 'RECIPIENT')),
      ],
      defaultId: 'imported-1',
    );
    final original = const BankBook();
    final after = BankBook(
      accounts: archived.accounts, defaultId: 'imported-1',
      centerLogoPath: '/new/center.png',
      footerLogoPath: '/new/footer.png',
    );
    final originalSettings = preferences({
      'ttx_vietqr_bank_book_v1': original.encode(),
    });
    final incomingSettings = preferences({
      'ttx_vietqr_bank_book_v1': archived.encode(),
    });
    final updated = preferences({
      'ttx_vietqr_bank_book_v1': after.encode(),
    });
    final report = BackupImportPostflight.verify(
      before: receipts({}), archive: receipts({}), after: receipts({}),
      beforeSettings: originalSettings,
      archiveSettings: incomingSettings,
      afterSettings: updated,
      archivedLogos: [
        BackupLogoAsset(
          slot: 'center', extension: 'png',
          bytes: Uint8List.fromList(
            const [137, 80, 78, 71, 13, 10, 26, 10])),
        BackupLogoAsset(
          slot: 'footer', extension: 'png',
          bytes: Uint8List.fromList(
            const [137, 80, 78, 71, 13, 10, 26, 10])),
      ],
    );
    expect(report.verifiedVietQrAccounts, 1);
    expect(report.verifiedVietQrLogos, 2);
    expect(report.preservedExistingSettings, 1);
  });

  test('postflight rejects replacing an existing VietQR account', () {
    final old = BankBook(
      accounts: [
        SavedBankAccount(
          id: 'existing', bankName: 'My Bank',
          account: const VietQrAccount(
            bankBin: '970407', accountNumber: '100',
            accountName: 'ORIGINAL')),
      ],
      defaultId: 'existing',
    );
    final tampered = BankBook(
      accounts: [
        SavedBankAccount(
          id: 'existing', bankName: 'My Bank',
          account: const VietQrAccount(
            bankBin: '970407', accountNumber: '100',
            accountName: 'CHANGED')),
      ],
      defaultId: 'existing',
    );
    expect(() => BackupImportPostflight.verify(
      before: receipts({}), archive: receipts({}), after: receipts({}),
      beforeSettings: preferences({
        'ttx_vietqr_bank_book_v1': old.encode(),
      }),
      archiveSettings: preferences({
        'ttx_vietqr_bank_book_v1': old.encode(),
      }),
      afterSettings: preferences({
        'ttx_vietqr_bank_book_v1': tampered.encode(),
      }),
    ), throwsFormatException);
  });
}
