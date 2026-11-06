import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
}
