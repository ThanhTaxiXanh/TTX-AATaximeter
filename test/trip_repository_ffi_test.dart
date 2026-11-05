import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/data/trip_session_snapshot.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';
import 'package:ttx_aataximeter/src/domain/trip_route_point.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> createV2Tables(Database db) async {
    await db.execute('''CREATE TABLE trips (
      id TEXT PRIMARY KEY,
      started_at TEXT NOT NULL,
      total_fare REAL NOT NULL,
      distance_km REAL NOT NULL,
      payload TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE active_trip (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      payload TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
  }

  Future<Database> dbForTest() async {
    return openDatabase(inMemoryDatabasePath, version: 3,
      onCreate: (db, version) async {
        await createV2Tables(db);
        await db.execute('''CREATE TABLE active_trip_route (
          sequence INTEGER PRIMARY KEY,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          recorded_at TEXT NOT NULL,
          accuracy_meters REAL NOT NULL,
          speed_kmh REAL NOT NULL,
          segment INTEGER NOT NULL
        )''');
      });
  }

  final t0 = DateTime(2026, 11, 5, 9);
  final tariff = TariffConfig.demo();

  List<TripRoutePoint> points(int count) => List.generate(count, (i) =>
      TripRoutePoint(
        latitude: 21.027 + i * 0.00001,
        longitude: 105.834 + i * 0.00001,
        recordedAt: t0.add(Duration(seconds: i * 5)),
        accuracyMeters: 4,
        speedKmh: 25,
        segment: i < count ~/ 2 ? 0 : 1,
      ));

  TripSessionSnapshot activeSnapshot(List<TripRoutePoint> route) {
    final engine = TaximeterEngine(tariff: tariff)..start(at: t0);
    engine.distanceMeters = 1234;
    engine.addToll(35000);
    return TripSessionSnapshot.fromEngine(engine,
      pickup: 'Ga Hà Nội',
      dropoff: 'Sân bay',
      fareProfileName: tariff.name,
      routePoints: route);
  }

  test('legacy full checkpoint replaced atomically by completed trip', () async {
    final db = await dbForTest();
    final repository = TripRepository(database: db);
    await repository.saveActive('{"trip":"state1"}');
    await repository.saveActive('{"trip":"state2"}');
    expect(await repository.loadActive(), '{"trip":"state2"}');

    final engine = TaximeterEngine(tariff: tariff)..start(at: t0);
    engine.distanceMeters = 15000;
    final receipt = engine.finish(at: t0.add(const Duration(minutes: 30)));
    final record = TripRecord.fromReceipt(receipt);
    await repository.completeActive(record);
    expect(await repository.loadActive(), isNull);
    expect((await repository.listTrips()).length, 1);
    expect((await repository.listTrips()).first.receipt.totalFare,
        receipt.totalFare);
    await repository.completeActive(record);
    expect((await repository.listTrips()).length, 1);
    await repository.dispose();
  });

  test('clearing finished trips preserves a live incremental checkpoint',
      () async {
    final db = await dbForTest();
    final repository = TripRepository(database: db);
    final snapshot = activeSnapshot(const []);
    await repository.beginActive(snapshot);
    await repository.clearAll();
    expect(await repository.loadActive(), isNotNull);
    await repository.clearActive();
    expect(await repository.loadActive(), isNull);
    expect(await db.query('active_trip_route'), isEmpty);
    await repository.dispose();
  });

  test('route is appended incrementally; header stays small', () async {
    final db = await dbForTest();
    final repo = TripRepository(database: db);
    final route = points(6);
    final snapshot = activeSnapshot(route);
    await repo.beginActive(snapshot);
    await repo.saveActiveIncremental(
      snapshot: snapshot,
      routeStartIndex: 0,
      appendedPoints: route.sublist(0, 2));
    var restored = TripSessionSnapshot.decode((await repo.loadActive())!);
    expect(restored.routePoints.length, 2);
    expect(restored.meter['distanceMeters'], 1234);
    expect(restored.tariff.baseFare, tariff.baseFare);
    expect(restored.pickup, 'Ga Hà Nội');
    final raw = (await db.query('active_trip')).single['payload'] as String;
    final header = jsonDecode(raw) as Map;
    expect(header['routeStorage'], 'sqlite-v3');
    expect(header['routeCount'], 2);
    expect(header['routePoints'], isEmpty);

    await repo.saveActiveIncremental(
      snapshot: snapshot,
      routeStartIndex: 2,
      appendedPoints: route.sublist(2));
    restored = TripSessionSnapshot.decode((await repo.loadActive())!);
    expect(restored.routePoints.length, 6);
    expect(restored.routePoints.map((p) => p.toJson()).toList(),
        route.map((p) => p.toJson()).toList());

    final meter = restored.restore(at: t0.add(const Duration(hours: 2)));
    expect(meter.requiresManualResume, isTrue);
    final receipt = meter.finish(at: t0.add(const Duration(hours: 2)));
    final record = TripRecord.fromReceipt(receipt,
      tariffSnapshot: tariff, routePoints: restored.routePoints);
    await repo.completeActive(record);
    expect(await repo.loadActive(), isNull);
    expect(await db.query('active_trip_route'), isEmpty);
    final finished = (await repo.listTrips()).single;
    expect(finished.routePoints.length, 6);
    expect(finished.receipt.totalFare, receipt.totalFare);
    await repo.dispose();
  });

  test('failed GPS-row insert rolls back BOTH route and fare checkpoint',
      () async {
    final db = await dbForTest();
    final repo = TripRepository(database: db);
    final route = points(4);
    final snapshot = activeSnapshot(route);
    await repo.beginActive(snapshot);
    await repo.saveActiveIncremental(
      snapshot: snapshot, routeStartIndex: 0,
      appendedPoints: route.sublist(0, 2));
    final before = await repo.loadActive();
    await db.execute('''CREATE TRIGGER fail_gps_insert
      BEFORE INSERT ON active_trip_route WHEN NEW.sequence = 2
      BEGIN SELECT RAISE(ABORT, 'simulated storage error'); END''');
    await expectLater(repo.saveActiveIncremental(
      snapshot: snapshot, routeStartIndex: 2,
      appendedPoints: route.sublist(2)), throwsA(isA<DatabaseException>()));
    expect(await repo.loadActive(), before);
    expect((await db.query('active_trip_route')).length, 2);
    await db.execute('DROP TRIGGER fail_gps_insert');
    // A repeated checkpoint can safely include already written points.
    await repo.saveActiveIncremental(
      snapshot: snapshot, routeStartIndex: 0, appendedPoints: route);
    expect((await db.query('active_trip_route')).length, 4);
    expect(TripSessionSnapshot.decode((await repo.loadActive())!)
        .routePoints.length, 4);
    await repo.dispose();
  });

  test('reject missing/stale route samples and replacing unfinished trip',
      () async {
    final db = await dbForTest();
    final repo = TripRepository(database: db);
    final route = points(3), snapshot = activeSnapshot(route);
    await repo.beginActive(snapshot);
    await expectLater(repo.beginActive(snapshot), throwsStateError);
    await expectLater(repo.saveActiveIncremental(
      snapshot: snapshot, routeStartIndex: 2,
      appendedPoints: [route[2]]), throwsStateError);
    expect((await db.query('active_trip_route')).length, 0);
    await repo.saveActiveIncremental(
      snapshot: snapshot, routeStartIndex: 0,
      appendedPoints: route);
    await expectLater(repo.saveActiveIncremental(
      snapshot: snapshot, routeStartIndex: 0,
      appendedPoints: route.take(2).toList()), throwsStateError);
    expect(TripSessionSnapshot.decode((await repo.loadActive())!)
        .routePoints.length, 3);
    await repo.dispose();
  });

  test('v2 database upgrade retains inline route until safely normalized',
      () async {
    final folder = await Directory.systemTemp.createTemp('ttx-sqlite-v3-');
    final dbPath = path.join(folder.path, 'legacy.db');
    try {
      final previous = await openDatabase(dbPath, version: 2,
        onCreate: (db, version) => createV2Tables(db));
      final legacyRoute = points(4);
      final legacy = activeSnapshot(legacyRoute);
      await previous.insert('active_trip', {
        'id': 1,
        'payload': legacy.encode(),
        'updated_at': t0.toUtc().toIso8601String(),
      });
      await previous.close();

      final repo = TripRepository(databasePath: dbPath);
      final before = TripSessionSnapshot.decode((await repo.loadActive())!);
      expect(before.routePoints.length, 4); // Inline v2 payload survived.
      final newRoute = [...legacyRoute, ...points(6).skip(4)];
      await repo.saveActiveIncremental(
        snapshot: activeSnapshot(newRoute), routeStartIndex: 0,
        appendedPoints: newRoute);
      final recovered = TripSessionSnapshot.decode((await repo.loadActive())!);
      expect(recovered.routePoints.length, 6);
      expect(recovered.routePoints.map((p) => p.toJson()).toList(),
          newRoute.map((p) => p.toJson()).toList());
      expect(recovered.meter['distanceMeters'], legacy.meter['distanceMeters']);
      expect((await repo.listTrips()), isEmpty);
      await repo.dispose();
    } finally {
      await deleteDatabase(dbPath);
      await folder.delete(recursive: true);
    }
  });
}
