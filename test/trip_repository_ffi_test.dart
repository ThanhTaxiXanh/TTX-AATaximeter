import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> dbForTest() async {
    return openDatabase(inMemoryDatabasePath, version: 2,
      onCreate: (db, version) async {
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
      });
  }

  test('checkpoint is atomically replaced by one finished trip', () async {
    final db = await dbForTest();
    final repository = TripRepository(database: db);
    await repository.saveActive('{"trip":"state1"}');
    await repository.saveActive('{"trip":"state2"}');
    expect(await repository.loadActive(), '{"trip":"state2"}');

    final t0 = DateTime(2026, 11, 4, 9);
    final engine = TaximeterEngine(tariff: TariffConfig.demo());
    engine.start(at: t0);
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

  test('discarding all finished trips does not clear a live checkpoint', () async {
    final db = await dbForTest();
    final repository = TripRepository(database: db);
    await repository.saveActive('{"meter":"running"}');
    await repository.clearAll();
    expect(await repository.loadActive(), '{"meter":"running"}');
    await repository.clearActive();
    expect(await repository.loadActive(), isNull);
    await repository.dispose();
  });
}
