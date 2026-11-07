import 'settings_backup_bundle.dart';
import 'trip_repository.dart';

/// Privacy-preserving, read-only comparison to support future restore design.
/// Counts intentionally never expose trip IDs, bank numbers or GPS coordinates.
/// This class has NO mutation methods.
class BackupDifferencePreview {
  const BackupDifferencePreview._({
    required this.archiveOnlyTrips,
    required this.deviceOnlyTrips,
    required this.changedTripPayloads,
    required this.identicalTrips,
    required this.archiveOnlySettings,
    required this.deviceOnlySettings,
    required this.changedSettings,
    required this.identicalSettings,
    required this.archiveActiveTrip,
    required this.deviceActiveTrip,
    required this.sameActiveTripStart,
  });

  final int archiveOnlyTrips;
  final int deviceOnlyTrips;
  final int changedTripPayloads;
  final int identicalTrips;
  final int archiveOnlySettings;
  final int deviceOnlySettings;
  final int changedSettings;
  final int identicalSettings;
  final bool archiveActiveTrip;
  final bool deviceActiveTrip;
  final bool sameActiveTripStart;

  /// A real restore must NEVER replace device-only trips or mismatched
  /// receipts silently, even if the archive itself is valid.
  bool get hasTripConflicts =>
      deviceOnlyTrips > 0 || changedTripPayloads > 0 ||
      deviceActiveTrip;

  bool get wouldAlterDeviceSettings =>
      archiveOnlySettings > 0 ||
      deviceOnlySettings > 0 ||
      changedSettings > 0;

  factory BackupDifferencePreview.compare({
    required TripBackupInspection archive,
    required TripBackupInspection device,
    required SettingsBackupBundle archiveSettings,
    required SettingsBackupBundle deviceSettings,
  }) {
    final backupTrips = archive.completedTripDigests;
    final deviceTrips = device.completedTripDigests;
    final overlap = backupTrips.keys.toSet()
        .intersection(deviceTrips.keys.toSet());
    var changedReceipts = 0;
    for (final tripId in overlap) {
      if (backupTrips[tripId] != deviceTrips[tripId]) {
        changedReceipts++;
      }
    }

    final originalSettings = deviceSettings.settings;
    final importedSettings = archiveSettings.settings;
    final sharedSettings = originalSettings.keys.toSet()
        .intersection(importedSettings.keys.toSet());
    var alteredSettings = 0;
    for (final key in sharedSettings) {
      if (originalSettings[key] != importedSettings[key]) {
        alteredSettings++;
      }
    }
    final archiveStart = archive.activeTripStartedAt;
    final deviceStart = device.activeTripStartedAt;
    return BackupDifferencePreview._(
      archiveOnlyTrips: backupTrips.length - overlap.length,
      deviceOnlyTrips: deviceTrips.length - overlap.length,
      changedTripPayloads: changedReceipts,
      identicalTrips: overlap.length - changedReceipts,
      archiveOnlySettings: importedSettings.length - sharedSettings.length,
      deviceOnlySettings: originalSettings.length - sharedSettings.length,
      changedSettings: alteredSettings,
      identicalSettings: sharedSettings.length - alteredSettings,
      archiveActiveTrip: archive.hasActiveTrip,
      deviceActiveTrip: device.hasActiveTrip,
      sameActiveTripStart: archive.hasActiveTrip && device.hasActiveTrip &&
          archiveStart != null && archiveStart == deviceStart,
    );
  }
}
