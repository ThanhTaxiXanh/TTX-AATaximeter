import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ttx_aataximeter/src/traffic_signs/data/traffic_sign_database.dart';
import 'package:ttx_aataximeter/src/traffic_signs/data/traffic_sign_repository.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';

void main() {
  sqfliteFfiInit();

  test('Android no-RTree error is recognized, other SQL failures are not', () {
    expect(isRtreeModuleUnavailable(
      'DatabaseException(no such module: rtree (code 1 SQLITE_ERROR); '
      'while compiling: SELECT sign_id FROM traffic_sign_rtree LIMIT 1)'), true);
    expect(isRtreeModuleUnavailable('no such table: traffic_sign_rtree'), false);
    expect(isRtreeModuleUnavailable('database disk image is malformed'), false);
  });

  test('full map and filtered viewport work with NO RTree table installed',
      () async {
    // Deliberately DO NOT CREATE VIRTUAL TABLE traffic_sign_rtree.
    // A working test here proves the coordinate fallback does not touch it.
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
    addTearDown(db.close);
    await db.execute('''
      CREATE TABLE traffic_signs (
        sign_id INTEGER PRIMARY KEY,
        longitude REAL NOT NULL, latitude REAL NOT NULL,
        sign_type_code INTEGER NOT NULL, direction_raw INTEGER NOT NULL,
        value_raw INTEGER NOT NULL, speed_kmh_inferred INTEGER,
        source_dataset TEXT NOT NULL,
        verification_status TEXT NOT NULL
      )
    ''');
    final batch = db.batch();
    // 151,228 rows are *not* allocated in Flutter; synthetic QA fixtures.
    for (var id = 0; id < 450; ++id) {
      batch.insert('traffic_signs', {
        'sign_id': id, 'longitude': 105.80 + id * 0.00001,
        'latitude': 21.00 + id * 0.00001,
        'sign_type_code': id.isEven ? 43 : 1,
        'direction_raw': 255, 'value_raw': 0,
        'speed_kmh_inferred': id.isEven ? 60 : null,
        'source_dataset': 'synthetic_test_only',
        'verification_status': 'unverified',
      });
    }
    batch.insert('traffic_signs', {
      'sign_id': 500, 'longitude': 110.0, 'latitude': 12.0,
      'sign_type_code': 1, 'direction_raw': 255,
      'value_raw': 0, 'speed_kmh_inferred': null,
      'source_dataset': 'synthetic_test_only',
      'verification_status': 'unverified',
    });
    await batch.commit(noResult: true);
    final repo = TrafficSignRepository(db, useRtree: false);
    const viewport = SignViewport(
      west: 105.75, east: 106.0, south: 20.9, north: 21.2);
    const enabled = TrafficSignFilter(enabled: true);

    final all = await repo.viewport(viewport, enabled);
    expect(all.total, 450);
    expect(all.items.length, lessThanOrEqualTo(
      TrafficSignRepository.maxVisibleItems));
    expect(all.items.fold<int>(0, (n, item) => n + item.count), 450);
    expect(all.items.any((item) => item.isCluster), isTrue);

    final speeds = await repo.viewport(viewport,
      const TrafficSignFilter(enabled: true, speedOnly: true));
    expect(speeds.total, 225);
    expect(speeds.items.every((item) => item.speedKmhInferred == 60), isTrue);

    final codes = await repo.viewport(viewport,
      const TrafficSignFilter(enabled: true, typeCode: 1));
    expect(codes.total, 225);
    expect(codes.items.every((item) => item.signId.isOdd), isTrue);

    // Raw ID and details are still retrieved from the original signed data.
    final single = await repo.byId(0);
    expect(single!.signId, 0);
    expect(single.verificationStatus, 'unverified');
    expect(await repo.availableTypeCodes(), [1, 43]);
    expect(repo.queryMetrics.queryCount, 3);
    expect(repo.queryMetrics.failureCount, 0);
  });

  test('fallback selects exactly matching edge coordinates', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
    addTearDown(db.close);
    await db.execute('''
      CREATE TABLE traffic_signs (
        sign_id INTEGER PRIMARY KEY,
        longitude REAL NOT NULL, latitude REAL NOT NULL,
        sign_type_code INTEGER NOT NULL, direction_raw INTEGER NOT NULL,
        value_raw INTEGER NOT NULL, speed_kmh_inferred INTEGER,
        source_dataset TEXT NOT NULL, verification_status TEXT NOT NULL
      )
    ''');
    for (final item in <(int, double, double)>[
      (0, 105.0, 21.0), (1, 106.0, 22.0), (2, 106.00001, 22.0),
    ]) {
      await db.insert('traffic_signs', {
        'sign_id': item.$1, 'longitude': item.$2, 'latitude': item.$3,
        'sign_type_code': 43, 'direction_raw': 0, 'value_raw': 0,
        'speed_kmh_inferred': null, 'source_dataset': 'synthetic_test_only',
        'verification_status': 'unverified',
      });
    }
    final repo = TrafficSignRepository(db, useRtree: false);
    final result = await repo.viewport(
      const SignViewport(west: 105, east: 106, south: 21, north: 22),
      const TrafficSignFilter(enabled: true),
    );
    expect(result.total, 2);
    expect(result.items.map((item) => item.signId), [0, 1]);
  });
}
