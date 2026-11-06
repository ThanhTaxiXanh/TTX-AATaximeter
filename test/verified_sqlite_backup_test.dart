import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/data/settings_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/backup_logo_asset.dart';
import 'package:ttx_aataximeter/src/data/unified_backup_bundle.dart';
import 'package:ttx_aataximeter/src/data/trip_session_snapshot.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';
import 'package:ttx_aataximeter/src/domain/trip_route_point.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('verified snapshot keeps completed receipts and active GPS journal '
      'without changing live SQLite', () async {
    final folder = await Directory.systemTemp.createTemp('ttx-backup-test-');
    final sourcePath = path.join(folder.path, 'live.db');
    TripRepository? source;
    TripRepository? restored;
    try {
      source = TripRepository(databasePath: sourcePath);
      final started = DateTime.utc(2026, 11, 6, 8);
      final tariff = TariffConfig.demo();
      final finishedMeter = TaximeterEngine(tariff: tariff)
        ..start(at: started);
      final receipt = finishedMeter.finish(
        at: started.add(const Duration(minutes: 15)));
      final finished = TripRecord.fromReceipt(receipt);
      await source.save(finished);

      final activeMeter = TaximeterEngine(tariff: tariff)
        ..start(at: started.add(const Duration(hours: 1)));
      final route = <TripRoutePoint>[
        TripRoutePoint(
          latitude: 21.027, longitude: 105.834,
          recordedAt: started.add(const Duration(hours: 1)),
          accuracyMeters: 4, speedKmh: 0, segment: 0),
        TripRoutePoint(
          latitude: 21.028, longitude: 105.835,
          recordedAt: started.add(const Duration(hours: 1, seconds: 12)),
          accuracyMeters: 4, speedKmh: 30, segment: 1),
      ];
      final state = TripSessionSnapshot.fromEngine(
        activeMeter, routePoints: route);
      await source.beginActive(state);
      await source.saveActiveIncremental(
        snapshot: state, routeStartIndex: 0, appendedPoints: route);

      final backup = await source.createVerifiedBackup(
        destinationDirectory: folder);
      expect(await backup.exists(), isTrue);
      expect(await backup.length(), greaterThan(0));
      final inspected = await TripRepository.inspectBackupFile(backup);
      expect(inspected.completedTripCount, 1);
      expect(inspected.hasActiveTrip, isTrue);
      expect(inspected.activeRouteCount, 2);

      final combined = UnifiedBackupBundle.fromParts(
        settings: SettingsBackupBundle.fromValues(const {}),
        sqliteBytes: await backup.readAsBytes(),
        logos: [
          BackupLogoAsset(
            slot: 'center', extension: 'png',
            bytes: Uint8List.fromList(
              const [137, 80, 78, 71, 13, 10, 26, 10, 5]),
          ),
        ],
      );
      final extracted = UnifiedBackupBundle.decode(combined.encode());
      expect(extracted.logos, hasLength(1));
      expect(extracted.logos.single.slot, 'center');
      final fromArchive = File(path.join(folder.path, 'extracted.db'));
      await fromArchive.writeAsBytes(extracted.sqliteBytes, flush: true);
      final archiveCheck = await TripRepository.inspectBackupFile(fromArchive);
      expect(archiveCheck.completedTripCount, 1);
      expect(archiveCheck.activeRouteCount, 2);

      restored = TripRepository(databasePath: backup.path);
      final history = await restored.listTrips();
      expect(history, hasLength(1));
      expect(history.single.id, finished.id);
      expect(history.single.receipt.totalFare, finished.receipt.totalFare);
      final active = TripSessionSnapshot.decode(
        (await restored.loadActive())!);
      expect(active.routePoints.map((p) => p.toJson()).toList(),
          route.map((p) => p.toJson()).toList());

      // Subsequent writes to the live file must not change its snapshot.
      await source.clearAll();
      await source.clearActive();
      expect(await source.listTrips(), isEmpty);
      expect(await source.loadActive(), isNull);
      expect((await restored.listTrips()).single.id, finished.id);
      expect(TripSessionSnapshot.decode((await restored.loadActive())!)
          .routePoints.length, 2);
      final currentInfo = await source.inspectCurrentData();
      final backupInfo = await TripRepository.inspectBackupFile(backup);
      expect(currentInfo.completedTripDigests, isEmpty);
      expect(currentInfo.hasActiveTrip, false);
      expect(backupInfo.completedTripDigests.keys, contains(finished.id));
      expect(backupInfo.activeRouteCount, 2);
    } finally {
      if (restored != null) await restored.dispose();
      if (source != null) await source.dispose();
      await folder.delete(recursive: true);
    }
  });

  test('preflight rejects SQLite GPS coordinates outside the valid range',
      () async {
    final folder = await Directory.systemTemp.createTemp('ttx-bad-gps-');
    final databasePath = path.join(folder.path, 'bad-gps.db');
    TripRepository? repo;
    try {
      repo = TripRepository(databasePath: databasePath);
      final at = DateTime.utc(2026, 11, 6, 9);
      final engine = TaximeterEngine(tariff: TariffConfig.demo())
        ..start(at: at);
      final snapshot = TripSessionSnapshot.fromEngine(engine);
      await repo.beginActive(snapshot);
      await repo.saveActiveIncremental(
        snapshot: snapshot,
        routeStartIndex: 0,
        appendedPoints: [
          TripRoutePoint(
            latitude: 21.028, longitude: 105.834,
            recordedAt: at, accuracyMeters: 4, speedKmh: 20),
        ],
      );
      await repo.dispose();
      repo = null;
      final db = await openDatabase(databasePath);
      try {
        await db.rawUpdate(
          'UPDATE active_trip_route SET latitude = 100 '
          'WHERE sequence = 0');
      } finally {
        await db.close();
      }
      await expectLater(
        TripRepository.inspectBackupFile(File(databasePath)),
        throwsFormatException,
      );
    } finally {
      if (repo != null) await repo.dispose();
      await folder.delete(recursive: true);
    }
  });

  test('preflight rejects a receipt payload with mismatched SQLite ID',
      () async {
    final folder = await Directory.systemTemp.createTemp('ttx-bad-id-');
    final dbPath = path.join(folder.path, 'bad-receipt.db');
    TripRepository? repo;
    try {
      repo = TripRepository(databasePath: dbPath);
      final at = DateTime.utc(2026, 11, 6, 10);
      final engine = TaximeterEngine(tariff: TariffConfig.demo())
        ..start(at: at);
      final record = TripRecord.fromReceipt(engine.finish(
        at: at.add(const Duration(minutes: 10))));
      await repo.save(record);
      await repo.dispose();
      repo = null;
      final db = await openDatabase(dbPath);
      try {
        final altered = Map<String, dynamic>.from(
          jsonDecode(record.encode()) as Map)
          ..['id'] = 'different-trip-id';
        await db.update('trips', {'payload': jsonEncode(altered)},
          where: 'id = ?', whereArgs: [record.id]);
      } finally {
        await db.close();
      }
      await expectLater(
        TripRepository.inspectBackupFile(File(dbPath)),
        throwsFormatException,
      );
    } finally {
      if (repo != null) await repo.dispose();
      await folder.delete(recursive: true);
    }
  });

}
