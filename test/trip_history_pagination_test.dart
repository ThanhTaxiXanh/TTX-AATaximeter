import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/data/trip_repository.dart';
import 'package:ttx_aataximeter/src/domain/revenue_summary.dart';
import 'package:ttx_aataximeter/src/domain/trip_record.dart';
import 'package:ttx_aataximeter/src/domain/trip_route_point.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> memory() => openDatabase(inMemoryDatabasePath,
    version: 3, singleInstance: false,
    onCreate: (db, version) async {
      await db.execute('''CREATE TABLE trips (
        id TEXT PRIMARY KEY, started_at TEXT NOT NULL,
        total_fare REAL NOT NULL, distance_km REAL NOT NULL,
        payload TEXT NOT NULL
      )''');
    });

  TripRecord ride(DateTime at, int seconds, {
    double fare = 15000, double km = 1, bool heavy = false,
  }) {
    final receipt = TripReceipt(
      startedAt: at, endedAt: at.add(Duration(seconds: seconds)),
      distanceKm: km, durationSeconds: seconds, waitingSeconds: 0,
      baseFare: fare, distanceFare: 0, waitingFare: 0,
      tollFee: 0, surcharge: 0, discount: 0,
      totalFare: fare, isFlatFare: false,
    );
    final route = heavy
        ? List.generate(200, (i) => TripRoutePoint(
            latitude: 21 + i * 0.00001, longitude: 105,
            recordedAt: at.add(Duration(seconds: i)),
            accuracyMeters: 5, speedKmh: 15, segment: 0))
        : <TripRoutePoint>[];
    return TripRecord.fromReceipt(receipt, routePoints: route);
  }

  test('SQL totals match legacy aggregation with empty/free/future trips', () async {
    final db = await memory();
    final repo = TripRepository(database: db);
    final day = DateTime.utc(2026, 11, 7, 1);
    final now = DateTime.utc(2026, 11, 7, 18);
    try {
      for (var i = 0; i < 60; i++) {
        await repo.save(ride(day.add(Duration(minutes: i)),
          120 + i, fare: 10000 + i * 100, km: i / 10 + 1,
          heavy: i.isEven));
      }
      final empty = ride(day.add(const Duration(hours: 2)), 0,
          fare: 0, km: 0);
      final free = ride(day.add(const Duration(hours: 2, minutes: 1)),
          60, fare: 0, km: 0);
      await repo.save(empty);
      await repo.save(free);
      await repo.save(ride(day.subtract(const Duration(days: 2)),
          45, fare: 11000, km: 2));
      await repo.save(ride(now.add(const Duration(days: 1)),
          45, fare: 22000, km: 2));

      // A mixed-offset database timestamp describes the same UTC instant.
      final offsetRide = ride(day, 120, fare: 10000, km: 1);
      await db.update('trips', {'started_at': '2026-11-07T08:00:00+07:00'},
        where: 'id = ?', whereArgs: [offsetRide.id]);

      for (final period in RevenuePeriod.values) {
        final original = RevenueSummary.calculate(await repo.listTrips(),
          period: period, now: now);
        final stats = await repo.readTripHistoryStats(
          period: period, now: now);
        expect(stats.tripCount, original.tripCount);
        expect(stats.totalFare, closeTo(original.totalFare, 0.001));
        expect(stats.totalDistanceKm,
            closeTo(original.totalDistanceKm, 0.001));
        expect(stats.averageFare, closeTo(original.averageFare, 0.001));
      }
      final totals = await repo.readTripHistoryStats(
        period: RevenuePeriod.all, now: now);
      expect(totals.tripCount, 62); // 60 normal + legitimate 0đ + old
      expect((await repo.listTrips()).length, 64); // empty and future included
    } finally {
      await repo.dispose();
    }
  });

  test('raw cursors yield no duplicates and never modify GPS route data',
      () async {
    final db = await memory();
    final repo = TripRepository(database: db);
    final day = DateTime.utc(2026, 11, 7, 1);
    final now = DateTime.utc(2026, 11, 7, 18);
    try {
      for (var i = 0; i < 52; i++) {
        await repo.save(ride(day.add(Duration(minutes: i)),
            i == 20 ? 0 : 80, fare: i == 20 ? 0 : 12000,
            km: i == 20 ? 0 : 1, heavy: i == 7));
      }
      var offset = 0;
      final ids = <String>[];
      var calls = 0;
      while (true) {
        final page = await repo.listTripsPage(
          period: RevenuePeriod.today, now: now,
          pageSize: 11, rawOffset: offset);
        calls++;
        ids.addAll(page.trips.map((x) => x.id));
        expect(page.nextRawOffset, greaterThan(offset));
        offset = page.nextRawOffset;
        if (!page.hasMore) break;
      }
      expect(calls, greaterThan(3));
      expect(ids.length, 51); // one zero/zero/zero test trip hidden
      expect(ids.toSet().length, 51);
      expect((await repo.listTrips()).length, 52); // unchanged database
      expect((await repo.listTrips()).singleWhere(
          (trip) => trip.routePoints.length == 200).routePoints.length, 200);
      await expectLater(repo.listTripsPage(
        period: RevenuePeriod.all, now: now, pageSize: 0), throwsRangeError);
    } finally {
      await repo.dispose();
    }
  });
}
