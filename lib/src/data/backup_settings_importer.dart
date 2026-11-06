import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../payment/bank_book.dart';
import 'backup_logo_asset.dart';
import 'settings_backup_bundle.dart';
import 'vietqr_merge_plan.dart';

/// Idempotent, additive settings import: an existing preference is NEVER
/// removed or updated. It cannot replace a bank account or fare preset.
class SettingsImportPlan {
  SettingsImportPlan._(this.missing, this.skippedExisting);

  final Map<String, String> missing;
  final int skippedExisting;

  factory SettingsImportPlan.compare({
    required SettingsBackupBundle archive,
    required SettingsBackupBundle device,
  }) {
    final toAdd = <String, String>{};
    var existing = 0;
    for (final item in archive.settings.entries) {
      if (device.settings.containsKey(item.key)) {
        existing++;
      } else {
        toAdd[item.key] = item.value;
      }
    }
    return SettingsImportPlan._(
      Map<String, String>.unmodifiable(toAdd), existing);
  }
}

class SettingsImportResult {
  const SettingsImportResult({
    required this.addedKeys,
    required this.skippedExistingKeys,
    required this.restoredLogos,
    required this.addedBankAccounts,
    required this.updatedBankBook,
  });
  final int addedKeys, skippedExistingKeys, restoredLogos;
  final int addedBankAccounts;
  final bool updatedBankBook;
}

class BackupSettingsImporter {
  static const _bankKey = 'ttx_vietqr_bank_book_v1';

  /// The caller must already have validated the complete backup and shown
  /// an explicit confirmation. Writes are additive and retryable.
  static Future<SettingsImportResult> importMissing({
    required SharedPreferencesAsync preferences,
    required SettingsBackupBundle archive,
    required List<BackupLogoAsset> logos,
    required Directory supportDirectory,
  }) async {
    final local = await SettingsBackupBundle.capture(preferences);
    final plan = SettingsImportPlan.compare(
      archive: archive, device: local);
    final missing = Map<String, String>.from(plan.missing)
      ..remove(_bankKey);

    // Preserve every pre-existing non-VietQR setting byte-for-byte.
    var added = 0;
    var skipped = plan.skippedExisting;
    for (final entry in missing.entries) {
      if (await preferences.getString(entry.key) != null) {
        skipped++;
        continue;
      }
      await preferences.setString(entry.key, entry.value);
      added++;
    }

    final rawBank = archive.settings[_bankKey];
    if (rawBank == null) {
      return SettingsImportResult(
        addedKeys: added, skippedExistingKeys: skipped,
        restoredLogos: 0, addedBankAccounts: 0,
        updatedBankBook: false);
    }

    final archivedBook = BankBook.decode(rawBank);
    // Always read the live book again immediately before the bank write.
    // The old importer incorrectly treated an existing EMPTY book as full.
    final localBank = await preferences.getString(_bankKey);
    final deviceBook =
        localBank == null ? const BankBook() : BankBook.decode(localBank);
    final recovery = VietQrMergePlan.compare(
      device: deviceBook, archive: archivedBook, logos: logos);
    final needsCreate = localBank == null;
    if (!needsCreate && !recovery.hasChanges) {
      return SettingsImportResult(
        addedKeys: added, skippedExistingKeys: skipped,
        restoredLogos: 0, addedBankAccounts: 0,
        updatedBankBook: false);
    }

    final restoredPaths = <String, String>{};
    for (final logo in logos) {
      if (!recovery.logoSlotsToAdd.contains(logo.slot)) continue;
      restoredPaths[logo.slot] = await _storePortableLogo(
        logo, supportDirectory);
    }
    final finalBook = BankBook(
      accounts: recovery.book.accounts,
      defaultId: recovery.book.defaultId,
      centerLogoPath: deviceBook.centerLogoPath ?? restoredPaths['center'],
      footerLogoPath: deviceBook.footerLogoPath ?? restoredPaths['footer'],
    );
    // Validate before committing one atomic SharedPreferences value.
    final encoded = finalBook.encode();
    await preferences.setString(_bankKey, encoded);
    if (needsCreate) added++;
    return SettingsImportResult(
      addedKeys: added,
      skippedExistingKeys: skipped,
      restoredLogos: restoredPaths.length,
      addedBankAccounts: recovery.accountsToAdd,
      updatedBankBook: !needsCreate,
    );
  }

  static Future<String> _storePortableLogo(
      BackupLogoAsset asset, Directory supportDir) async {
    final logoDir = Directory(
      path.join(supportDir.path, 'ttx_qr_logos'));
    await logoDir.create(recursive: true);
    final supportCanonical = await supportDir.resolveSymbolicLinks();
    final logoCanonical = await logoDir.resolveSymbolicLinks();
    if (!path.isWithin(supportCanonical, logoCanonical)) {
      throw const FormatException(
        'Thư mục logo nằm ngoài dữ liệu ứng dụng');
    }
    final fingerprint = sha256.convert(asset.bytes).toString();
    final basename = '${asset.slot}_restored_'
        '${fingerprint.substring(0, 24)}.${asset.extension}';
    final destination = File(path.join(logoDir.path, basename));
    if (await destination.exists()) {
      final existing = await destination.readAsBytes();
      if (sha256.convert(existing).toString() != fingerprint) {
        throw const FormatException(
          'Logo đã lưu trùng tên nhưng khác nội dung');
      }
      return destination.path;
    }
    final temporary = File('${destination.path}.tmp');
    if (await temporary.exists()) {
      await temporary.delete();
    }
    try {
      await temporary.writeAsBytes(asset.bytes, flush: true);
      if (await destination.exists()) {
        throw StateError('Logo đích đã tồn tại trong khi đang nhập');
      }
      await temporary.rename(destination.path);
      return destination.path;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
