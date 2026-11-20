import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ttx_aataximeter/src/traffic_signs/data/traffic_sign_repository.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late TrafficSignRepository repository;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await db.execute('''
      CREATE TABLE traffic_signs (
        sign_id INTEGER PRIMARY KEY,
        longitude REAL NOT NULL,
        latitude REAL NOT NULL,
        sign_type_code INTEGER NOT NULL,
        direction_raw INTEGER NOT NULL,
        value_raw INTEGER NOT NULL,
        speed_kmh_inferred INTEGER,
        source_dataset TEXT NOT NULL,
        verification_status TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE traffic_sign_rtree USING rtree(
        sign_id, min_longitude, max_longitude, min_latitude, max_latitude)
    ''');
    repository = TrafficSignRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> add(int id, double lon, double lat,
      {int? speed, int code = 1}) async {
    await db.insert('traffic_signs', {
      'sign_id': id, 'longitude': lon, 'latitude': lat,
      'sign_type_code': code, 'direction_raw': 255,
      'value_raw': 0, 'speed_kmh_inferred': speed,
      'source_dataset': 'synthetic_test_only',
      'verification_status': 'unverified',
    });
    await db.insert('traffic_sign_rtree', {
      'sign_id': id, 'min_longitude': lon, 'max_longitude': lon,
      'min_latitude': lat, 'max_latitude': lat,
    });
  }

  const region = SignViewport(
    west: 105, south: 20, east: 107, north: 22,
  );

  test('sign ID zero, raw attributes and exact viewport selection', () async {
    await add(0, 105.8, 21.0);
    await add(1, 106.1, 21.0, speed: 60);
    await add(2, 110.0, 21.0);

    final zero = await repository.byId(0);
    expect(zero, isNotNull);
    expect(zero!.signId, 0);
    expect(zero.directionRaw, 255);
    expect(zero.verificationStatus, 'unverified');

    final all = await repository.viewport(
      region, const TrafficSignFilter(enabled: true));
    expect(all.total, 2);
    expect(all.items.map((s) => s.signId), [0, 1]);
    expect(all.items.every((s) => !s.isCluster), isTrue);

    final disabled = await repository.viewport(
      region, const TrafficSignFilter(enabled: false));
    expect(disabled.total, 0);
  });

  test('filter inferred speed and filter raw type code without inference', () async {
    await add(0, 105.8, 21.0, code: 43);
    await add(1, 106.1, 21.0, speed: 60, code: 1);
    await add(2, 106.3, 21.0, code: 1);
    final inferred = await repository.viewport(
      region, const TrafficSignFilter(enabled: true, speedOnly: true));
    expect(inferred.total, 1);
    expect(inferred.items.single.speedKmhInferred, 60);

    final type = await repository.viewport(region,
      const TrafficSignFilter(enabled: true, typeCode: 43));
    expect(type.total, 1);
    expect(type.items.single.signId, 0);
    expect(await repository.availableTypeCodes(), [1, 43]);
  });

  test('RTree groups dense viewport without losing aggregate counts', () async {
    // Synthetic points only; no fabricated production traffic sign data.
    final batch = db.batch();
    for (var id = 0; id < 360; id++) {
      final lon = 105.0 + id / 10000;
      final lat = 21.0 + id / 20000;
      batch.insert('traffic_signs', {
        'sign_id': id, 'longitude': lon, 'latitude': lat,
        'sign_type_code': 1, 'direction_raw': 255,
        'value_raw': 0, 'speed_kmh_inferred': null,
        'source_dataset': 'synthetic_test_only',
        'verification_status': 'unverified',
      });
      batch.insert('traffic_sign_rtree', {
        'sign_id': id, 'min_longitude': lon, 'max_longitude': lon,
        'min_latitude': lat, 'max_latitude': lat,
      });
    }
    await batch.commit(noResult: true);
    final result = await repository.viewport(
      region, const TrafficSignFilter(enabled: true));
    expect(result.total, 360);
    expect(result.items.length,
      lessThanOrEqualTo(TrafficSignRepository.maxVisibleItems));
    expect(result.items.fold<int>(0, (sum, item) => sum + item.count), 360);
    expect(result.items.any((item) => item.isCluster), isTrue);
  });

  test('rejects invalid viewport without querying SQLite', () async {
    final result = await repository.viewport(
      const SignViewport(west: 120, east: 100, south: 0, north: 10),
      const TrafficSignFilter(enabled: true));
    expect(result.total, 0);
  });
}
