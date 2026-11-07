import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import 'trip_repository.dart';
import 'unified_backup_bundle.dart';

/// Private pre-import safety snapshots. They must stay available after an
/// additive import even if restoring an archive or refreshing the UI fails.
/// All methods are read-only: no deleting, editing or importing is supported.
class PreImportBackupVault {
  static const directoryName = 'ttx_pre_import_safety';

  static Future<List<PreImportSafetyFile>> list(
      Directory appSupportDirectory) async {
    final vault = Directory(
      path.join(appSupportDirectory.path, directoryName));
    if (!await vault.exists()) return const [];
    final supportReal = await appSupportDirectory.resolveSymbolicLinks();
    final vaultReal = await vault.resolveSymbolicLinks();
    if (!path.isWithin(supportReal, vaultReal)) {
      throw const FormatException(
        'Thư mục dự phòng nằm ngoài dữ liệu ứng dụng');
    }

    final result = <PreImportSafetyFile>[];
    await for (final entity in vault.list(followLinks: false)) {
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) continue;
      final filename = path.basename(entity.path);
      if (!RegExp(r'^truoc_nhap_[0-9]{12,20}\.ttxbackup$')
          .hasMatch(filename)) continue;
      final file = File(entity.path);
      final info = await file.stat();
      if (info.size <= 0 ||
          info.size > UnifiedBackupBundle.maxBundleBytes) continue;
      result.add(PreImportSafetyFile(
        file: file,
        byteLength: info.size,
        modifiedAt: info.modified,
      ));
    }
    result.sort((a, b) => b.file.path.compareTo(a.file.path));
    return List<PreImportSafetyFile>.unmodifiable(result);
  }

  /// Verifies exactly the bytes that the UI will offer to save externally.
  /// A stale or corrupt private copy is never offered as a verified backup.
  static Future<VerifiedPreImportBackup> verify({
    required PreImportSafetyFile entry,
    required Directory temporaryDirectory,
  }) async {
    if (await FileSystemEntity.type(entry.file.path,
        followLinks: false) != FileSystemEntityType.file) {
      throw const FormatException('Tệp dự phòng không còn là tệp hợp lệ');
    }
    final actualLength = await entry.file.length();
    if (actualLength <= 0 ||
        actualLength > UnifiedBackupBundle.maxBundleBytes) {
      throw const FormatException('Tệp dự phòng có dung lượng bất thường');
    }
    final bytes = await entry.file.readAsBytes();
    final bundle = UnifiedBackupBundle.decode(bytes);
    final scratch = await temporaryDirectory.createTemp('ttx-vault-check-');
    try {
      final sqlite = File(path.join(scratch.path, 'archive.db'));
      await sqlite.writeAsBytes(bundle.sqliteBytes, flush: true);
      final inspection = await TripRepository.inspectBackupFile(sqlite);
      return VerifiedPreImportBackup(
        bytes: bytes,
        createdAtUtc: bundle.createdAtUtc,
        completedTrips: inspection.completedTripCount,
        activeTripSkipped: inspection.hasActiveTrip,
        settingsCount: bundle.settings.settings.length,
        logoCount: bundle.logos.length,
      );
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }
}

class PreImportSafetyFile {
  const PreImportSafetyFile({
    required this.file,
    required this.byteLength,
    required this.modifiedAt,
  });

  final File file;
  final int byteLength;
  final DateTime modifiedAt;
}

/// An immutable summary and the exact verified archive bytes; never expose
/// the raw content to on-screen labels, console or error logs.
class VerifiedPreImportBackup {
  VerifiedPreImportBackup({
    required Uint8List bytes,
    required this.createdAtUtc,
    required this.completedTrips,
    required this.activeTripSkipped,
    required this.settingsCount,
    required this.logoCount,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final DateTime createdAtUtc;
  final int completedTrips;
  final bool activeTripSkipped;
  final int settingsCount;
  final int logoCount;
}
