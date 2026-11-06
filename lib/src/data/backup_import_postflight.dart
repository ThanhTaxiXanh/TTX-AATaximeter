import 'settings_backup_bundle.dart';
import 'trip_repository.dart';

/// Verify that an additive import preserved every pre-existing item and
/// actually inserted every archive-only receipt. This is read-only.
/// A mismatch is an error, not a reason to auto-delete or overwrite records.
class BackupImportPostflight {
  const BackupImportPostflight._({
    required this.verifiedNewTrips,
    required this.verifiedNewSettings,
    required this.preservedExistingTrips,
    required this.preservedExistingSettings,
  });

  final int verifiedNewTrips;
  final int verifiedNewSettings;
  final int preservedExistingTrips;
  final int preservedExistingSettings;

  static BackupImportPostflight verify({
    required TripBackupInspection before,
    required TripBackupInspection archive,
    required TripBackupInspection after,
    required SettingsBackupBundle beforeSettings,
    required SettingsBackupBundle archiveSettings,
    required SettingsBackupBundle afterSettings,
  }) {
    if (before.hasActiveTrip || after.hasActiveTrip) {
      throw StateError(
        'Không thể xác nhận nhập khi máy còn chuyến đang hoạt động');
    }

    final beforeTrips = before.completedTripDigests;
    final archiveTrips = archive.completedTripDigests;
    final afterTrips = after.completedTripDigests;

    for (final entry in beforeTrips.entries) {
      if (afterTrips[entry.key] != entry.value) {
        throw const FormatException(
          'Dữ liệu chuyến có trước khi nhập đã bị thay đổi');
      }
    }
    var newTrips = 0;
    for (final entry in archiveTrips.entries) {
      if (beforeTrips.containsKey(entry.key)) continue;
      if (afterTrips[entry.key] != entry.value) {
        throw const FormatException(
          'Một chuyến cần nhập còn thiếu hoặc sai nội dung');
      }
      newTrips++;
    }
    if (afterTrips.length != beforeTrips.length + newTrips) {
      throw const FormatException(
        'Số lượng chuyến sau nhập không khớp');
    }

    final oldSettings = beforeSettings.settings;
    final incomingSettings = archiveSettings.settings;
    final resultSettings = afterSettings.settings;
    for (final item in oldSettings.entries) {
      if (resultSettings[item.key] != item.value) {
        throw const FormatException(
          'Cấu hình đã lưu trước khi nhập bị thay đổi');
      }
    }
    var newSettings = 0;
    for (final item in incomingSettings.entries) {
      if (oldSettings.containsKey(item.key)) continue;
      // The bank book may have valid new device-specific logo paths,
      // so compare presence, not raw bytes of its old absolute paths.
      if (!resultSettings.containsKey(item.key)) {
        throw const FormatException(
          'Một nhóm cấu hình cần nhập vẫn chưa được lưu');
      }
      newSettings++;
    }
    if (resultSettings.length != oldSettings.length + newSettings) {
      throw const FormatException(
        'Số lượng nhóm cấu hình sau nhập không khớp');
    }

    return BackupImportPostflight._(
      verifiedNewTrips: newTrips,
      verifiedNewSettings: newSettings,
      preservedExistingTrips: beforeTrips.length,
      preservedExistingSettings: oldSettings.length,
    );
  }
}
