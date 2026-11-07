import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/data/backup_difference_preview.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';

void main() {
  TripBackupInspection trips(
    Map<String, String> receipts, {
    bool active = false,
    String? started,
  }) => TripBackupInspection(
    completedTripCount: receipts.length,
    completedTripDigests: Map<String, String>.unmodifiable(receipts),
    hasActiveTrip: active, activeRouteCount: active ? 2 : 0,
    activeTripStartedAt: started,
  );

  SettingsBackupBundle settings(Map<String, String> values) =>
    SettingsBackupBundle.fromValues(values);

  test('reports receipt overlap, missing items and same-ID content conflicts',
      () {
    final result = BackupDifferencePreview.compare(
      archive: trips({'shared': 'same', 'archive': 'a', 'changed': 'old'}),
      device: trips({'shared': 'same', 'device': 'd', 'changed': 'new'}),
      archiveSettings: settings({}),
      deviceSettings: settings({}),
    );
    expect(result.archiveOnlyTrips, 1);
    expect(result.deviceOnlyTrips, 1);
    expect(result.identicalTrips, 1);
    expect(result.changedTripPayloads, 1);
    expect(result.hasTripConflicts, true);
  });

  test('compares settings without displaying raw bank/account data', () {
    final preferenceA =
      const DashboardPreferences(default3D: true).encode();
    final preferenceB =
      const DashboardPreferences(default3D: false).encode();
    final result = BackupDifferencePreview.compare(
      archive: trips({}), device: trips({}),
      archiveSettings: settings({
        DashboardPreferences.storageKey: preferenceA,
      }),
      deviceSettings: settings({
        DashboardPreferences.storageKey: preferenceB,
        'ttx_vietqr_bank_book_v1':
          '{"version":1,"accounts":[]}',
      }),
    );
    expect(result.changedSettings, 1);
    expect(result.deviceOnlySettings, 1);
    expect(result.archiveOnlySettings, 0);
    expect(result.wouldAlterDeviceSettings, true);
    expect(result.hasTripConflicts, false);
  });

  test('flags an unfinished device trip even when receipts match', () {
    final summary = BackupDifferencePreview.compare(
      archive: trips({'one': 'same'},
        active: true, started: '2026-11-06T08:00:00.000Z'),
      device: trips({'one': 'same'},
        active: true, started: '2026-11-06T08:00:00.000Z'),
      archiveSettings: settings({}), deviceSettings: settings({}),
    );
    expect(summary.sameActiveTripStart, isTrue);
    expect(summary.hasTripConflicts, isTrue);
    expect(summary.identicalTrips, 1);
  });

  test('empty device versus archive is not a hidden conflict', () {
    final result = BackupDifferencePreview.compare(
      archive: trips({'trip1': 'sha'}),
      device: trips({}),
      archiveSettings: settings({}),
      deviceSettings: settings({}),
    );
    expect(result.archiveOnlyTrips, 1);
    expect(result.deviceOnlyTrips, 0);
    expect(result.changedTripPayloads, 0);
    expect(result.hasTripConflicts, false);
  });
}
