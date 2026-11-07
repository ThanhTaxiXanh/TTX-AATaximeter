import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ttx_aataximeter/src/data/backup_import_postflight.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/data/trip_session_snapshot.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';

TripRecord receipt(int hour) {
  final at = DateTime.utc(2026, 11, 6, hour);
  final engine = TaximeterEngine(tariff: TariffConfig.demo())
    ..start(at: at);
  return TripRecord.fromReceipt(
    engine.finish(at: at.add(const Duration(minutes: 15))));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('import adds only absent receipts and never overwrites same-ID fares',
      () async {
    final root = await Directory.systemTemp.createTemp('ttx-merge-test-');
    TripRepository? origin;
    TripRepository? destination;
    try {
      origin = TripRepository(databasePath: path.join(root.path, 'origin.db'));
      destination = TripRepository(
        databasePath: path.join(root.path, 'destination.db'));
      final shared = receipt(8);
      final onlyArchive = receipt(9);
      final existing = receipt(10);
      await origin.save(shared);
      await origin.save(onlyArchive);
      await destination.save(
        shared.copyWith(paymentMethod: PaymentMethod.bankTransfer));
      await destination.save(existing);
      final running = TaximeterEngine(tariff: TariffConfig.demo())
        ..start(at: DateTime.utc(2026, 11, 6, 11));
      await origin.beginActive(TripSessionSnapshot.fromEngine(running));
      final snapshot = await origin.createVerifiedBackup(
        destinationDirectory: root);

      final result = await destination.importMissingCompletedTrips(snapshot);
      expect(result.imported, 1);
      expect(result.conflictsSkipped, 1);
      expect(result.identical, 0);
      expect(result.unfinishedBackupSkipped, true);
      final after = await destination.listTrips();
      expect(after, hasLength(3));
      expect(after.firstWhere((x) => x.id == shared.id).paymentMethod,
        PaymentMethod.bankTransfer);
      expect(await destination.loadActive(), isNull);

      final repeated = await destination.importMissingCompletedTrips(snapshot);
      expect(repeated.imported, 0);
      expect(repeated.conflictsSkipped, 1);
      expect(repeated.identical, 1);
      expect((await destination.listTrips()).length, 3);
    } finally {
      if (origin != null) await origin.dispose();
      if (destination != null) await destination.dispose();
      await root.delete(recursive: true);
    }
  });

  test('import refuses to modify a phone with an unfinished trip', () async {
    final root = await Directory.systemTemp.createTemp('ttx-active-merge-');
    TripRepository? origin;
    TripRepository? destination;
    try {
      origin = TripRepository(databasePath: path.join(root.path, 'old.db'));
      destination = TripRepository(databasePath: path.join(root.path, 'now.db'));
      await origin.save(receipt(8));
      final backup = await origin.createVerifiedBackup(
        destinationDirectory: root);
      final running = TaximeterEngine(tariff: TariffConfig.demo())
        ..start(at: DateTime.utc(2026, 11, 6, 11));
      await destination.beginActive(TripSessionSnapshot.fromEngine(running));
      await expectLater(
        destination.importMissingCompletedTrips(backup),
        throwsStateError);
      expect(await destination.listTrips(), isEmpty);
      expect(await destination.loadActive(), isNotNull);
    } finally {
      if (origin != null) await origin.dispose();
      if (destination != null) await destination.dispose();
      await root.delete(recursive: true);
    }
  });

  test('same archived receipt imports exactly once on an empty phone',
      () async {
    final root = await Directory.systemTemp.createTemp('ttx-empty-import-');
    TripRepository? origin;
    TripRepository? destination;
    try {
      origin = TripRepository(databasePath: path.join(root.path, 'history.db'));
      destination = TripRepository(databasePath: path.join(root.path, 'new.db'));
      await origin.save(receipt(8));
      await origin.save(receipt(9));
      final snapshot = await origin.createVerifiedBackup(
        destinationDirectory: root);
      final a = await destination.importMissingCompletedTrips(snapshot);
      final b = await destination.importMissingCompletedTrips(snapshot);
      expect(a.imported, 2);
      expect(b.imported, 0);
      expect(b.identical, 2);
      expect((await destination.listTrips()).length, 2);
    } finally {
      if (origin != null) await origin.dispose();
      if (destination != null) await destination.dispose();
      await root.delete(recursive: true);
    }
  });
  test('preserves reordered legacy receipt bytes and verifies postflight',
      () async {
    final root = await Directory.systemTemp.createTemp('ttx-legacy-json-');
    final targetPath = path.join(root.path, 'target.db');
    TripRepository? source;
    TripRepository? target;
    try {
      source = TripRepository(databasePath: path.join(root.path, 'source.db'));
      target = TripRepository(databasePath: targetPath);
      final record = receipt(12);
      await source.save(record);
      final snapshot = await source.createVerifiedBackup(
        destinationDirectory: root);
      final json = Map<String, dynamic>.from(
        jsonDecode(record.encode()) as Map);
      final reordered = jsonEncode(
        Map<String, dynamic>.fromEntries(json.entries.toList().reversed));
      expect(reordered, isNot(record.encode()));
      final editableCopy = await openDatabase(snapshot.path);
      try {
        await editableCopy.update('trips', {'payload': reordered},
          where: 'id = ?', whereArgs: [record.id]);
      } finally {
        await editableCopy.close();
      }
      final before = await target.inspectCurrentData();
      final archive = await TripRepository.inspectBackupFile(snapshot);
      final first = await target.importMissingCompletedTrips(snapshot);
      expect(first.imported, 1);
      final second = await target.importMissingCompletedTrips(snapshot);
      expect(second.imported, 0);
      expect(second.identical, 1);
      final after = await target.inspectCurrentData();
      final verified = BackupImportPostflight.verify(
        before: before, archive: archive, after: after,
        beforeSettings: SettingsBackupBundle.fromValues(const {}),
        archiveSettings: SettingsBackupBundle.fromValues(const {}),
        afterSettings: SettingsBackupBundle.fromValues(const {}),
      );
      expect(verified.verifiedNewTrips, 1);
      await target.dispose();
      target = null; // Inspect raw SQLite only after the repository closes.
      final live = await openDatabase(targetPath);
      try {
        final rows = await live.query('trips', columns: ['payload'],
          where: 'id = ?', whereArgs: [record.id]);
        expect(rows.single['payload'], reordered);
      } finally {
        await live.close();
      }
    } finally {
      if (source != null) await source.dispose();
      if (target != null) await target.dispose();
      await root.delete(recursive: true);
    }
  });

}
