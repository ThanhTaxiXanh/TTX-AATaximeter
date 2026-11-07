import 'settings_backup_bundle.dart';
import '../payment/bank_book.dart';
import 'backup_logo_asset.dart';
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
    required this.verifiedVietQrAccounts,
    required this.verifiedVietQrLogos,
  });

  final int verifiedNewTrips;
  final int verifiedNewSettings;
  final int preservedExistingTrips;
  final int preservedExistingSettings;
  final int verifiedVietQrAccounts;
  final int verifiedVietQrLogos;

  static BackupImportPostflight verify({
    required TripBackupInspection before,
    required TripBackupInspection archive,
    required TripBackupInspection after,
    required SettingsBackupBundle beforeSettings,
    required SettingsBackupBundle archiveSettings,
    required SettingsBackupBundle afterSettings,
    List<BackupLogoAsset> archivedLogos = const [],
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
    const bankKey = 'ttx_vietqr_bank_book_v1';
    for (final item in oldSettings.entries) {
      if (item.key == bankKey && incomingSettings.containsKey(bankKey)) {
        continue; // Bank book allows ADDITIONS only; validated below.
      }
      if (resultSettings[item.key] != item.value) {
        throw const FormatException(
          'Cấu hình đã lưu trước khi nhập bị thay đổi');
      }
    }

    var verifiedAccounts = 0;
    var verifiedLogos = 0;
    if (incomingSettings.containsKey(bankKey)) {
      final oldBank = oldSettings[bankKey] == null
          ? const BankBook() : BankBook.decode(oldSettings[bankKey]!);
      final archiveBank = BankBook.decode(incomingSettings[bankKey]!);
      final finalBankRaw = resultSettings[bankKey];
      if (finalBankRaw == null) {
        throw const FormatException('Thiếu danh bạ VietQR sau khi nhập');
      }
      final finalBank = BankBook.decode(finalBankRaw);
      String identity(SavedBankAccount x) =>
          '${x.account.bankBin}:${x.account.accountNumber}';

      // Every pre-existing bank account must retain its ID, bank name and
      // account details; a pre-existing selected default cannot change.
      for (final current in oldBank.accounts) {
        if (!finalBank.accounts.any((candidate) =>
            candidate.id == current.id &&
            candidate.bankName == current.bankName &&
            candidate.account.bankBin == current.account.bankBin &&
            candidate.account.accountNumber == current.account.accountNumber &&
            candidate.account.accountName == current.account.accountName)) {
          throw const FormatException(
            'Tài khoản VietQR đang có đã bị thay đổi');
        }
      }
      if (oldBank.accounts.isNotEmpty &&
          oldBank.defaultId != finalBank.defaultId ||
          oldBank.centerLogoPath != null &&
              oldBank.centerLogoPath != finalBank.centerLogoPath ||
          oldBank.footerLogoPath != null &&
              oldBank.footerLogoPath != finalBank.footerLogoPath) {
        throw const FormatException(
          'Tài khoản hoặc logo VietQR hiện có đã bị thay đổi');
      }

      final oldIdentities = oldBank.accounts.map(identity).toSet();
      final archiveIdentities = archiveBank.accounts.map(identity).toSet();
      final afterIdentities = finalBank.accounts.map(identity).toSet();
      final expected = {...oldIdentities, ...archiveIdentities};
      if (!afterIdentities.containsAll(expected) ||
          finalBank.accounts.length != expected.length) {
        throw const FormatException(
          'Thiếu tài khoản VietQR hoặc xuất hiện tài khoản ngoài dự kiến');
      }
      verifiedAccounts = archiveIdentities.difference(oldIdentities).length;
      for (final asset in archivedLogos) {
        if (asset.slot == 'center' && oldBank.centerLogoPath == null) {
          if (finalBank.centerLogoPath == null) {
            throw const FormatException('Chưa khôi phục logo giữa VietQR');
          }
          verifiedLogos++;
        } else if (asset.slot == 'footer' && oldBank.footerLogoPath == null) {
          if (finalBank.footerLogoPath == null) {
            throw const FormatException('Chưa khôi phục logo dưới VietQR');
          }
          verifiedLogos++;
        }
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
      verifiedVietQrAccounts: verifiedAccounts,
      verifiedVietQrLogos: verifiedLogos,
    );
  }
}
