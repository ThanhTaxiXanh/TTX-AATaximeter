import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/pre_import_backup_vault.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/data/unified_backup_bundle.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('vault starts empty and ignores non-backup files', () async {
    final root = await Directory.systemTemp.createTemp('ttx-vault-empty-');
    try {
      expect(await PreImportBackupVault.list(root), isEmpty);
      final vault = Directory(path.join(root.path,
          PreImportBackupVault.directoryName));
      await vault.create();
      await File(path.join(vault.path, 'another_file.txt'))
          .writeAsString('not a backup');
      await File(path.join(vault.path, 'truoc_nhap_111111111111.ttxbackup'))
          .writeAsBytes([1, 2, 3]);
      final all = await PreImportBackupVault.list(root);
      expect(all, hasLength(1));
      await expectLater(
        PreImportBackupVault.verify(
          entry: all.single, temporaryDirectory: root),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('valid private backup is inspected and its bytes stay unchanged',
      () async {
    final root = await Directory.systemTemp.createTemp('ttx-vault-valid-');
    TripRepository? repo;
    try {
      repo = TripRepository(
        databasePath: path.join(root.path, 'source.db'));
      final started = DateTime.utc(2026, 11, 6, 10);
      final engine = TaximeterEngine(tariff: TariffConfig.demo())
        ..start(at: started);
      final receipt = TripRecord.fromReceipt(engine.finish(
        at: started.add(const Duration(minutes: 10))));
      await repo.save(receipt);
      final sqlite = await repo.createVerifiedBackup(
        destinationDirectory: root);
      final archive = UnifiedBackupBundle.fromParts(
        sqliteBytes: await sqlite.readAsBytes(),
        settings: SettingsBackupBundle.fromValues(const {}),
        createdAtUtc: DateTime.utc(2026, 11, 6, 11));
      final vault = Directory(path.join(root.path,
          PreImportBackupVault.directoryName));
      await vault.create();
      final file = File(path.join(vault.path,
          'truoc_nhap_1793970000000000.ttxbackup'));
      final exact = archive.encode();
      await file.writeAsBytes(exact, flush: true);
      final entries = await PreImportBackupVault.list(root);
      expect(entries, hasLength(1));
      expect(entries.single.byteLength, exact.length);
      final verified = await PreImportBackupVault.verify(
        entry: entries.single, temporaryDirectory: root);
      expect(verified.bytes, exact);
      expect(verified.completedTrips, 1);
      expect(verified.activeTripSkipped, false);
      expect(verified.settingsCount, 0);
      expect(verified.logoCount, 0);
      expect(verified.createdAtUtc, DateTime.utc(2026, 11, 6, 11));
      expect(await file.readAsBytes(), exact);
    } finally {
      if (repo != null) await repo.dispose();
      await root.delete(recursive: true);
    }
  });

  test('corrupt archived bytes cannot be exported as verified', () async {
    final root = await Directory.systemTemp.createTemp('ttx-vault-corrupt-');
    TripRepository? repo;
    try {
      repo = TripRepository(
        databasePath: path.join(root.path, 'live.db'));
      // Initialize the valid v3 schema, without fabricating receipt rows.
      await repo.listTrips();
      final sqlite = await repo.createVerifiedBackup(
        destinationDirectory: root);
      final archive = UnifiedBackupBundle.fromParts(
        sqliteBytes: await sqlite.readAsBytes(),
        settings: SettingsBackupBundle.fromValues(const {}));
      final bytes = archive.encode();
      bytes[bytes.length - 1] ^= 0x80;
      final vault = Directory(path.join(root.path,
          PreImportBackupVault.directoryName));
      await vault.create();
      final file = File(path.join(vault.path,
          'truoc_nhap_1793970000000001.ttxbackup'));
      await file.writeAsBytes(bytes);
      final entries = await PreImportBackupVault.list(root);
      await expectLater(
        PreImportBackupVault.verify(
          entry: entries.single, temporaryDirectory: root),
        throwsFormatException);
      expect(await file.exists(), isTrue); // Inspection never deletes copies.
    } finally {
      if (repo != null) await repo.dispose();
      await root.delete(recursive: true);
    }
  });
}
