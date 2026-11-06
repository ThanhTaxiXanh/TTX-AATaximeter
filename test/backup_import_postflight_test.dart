import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/data/backup_import_postflight.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';
import 'package:ttx_aataximeter/src/payment/bank_book.dart';

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
}
