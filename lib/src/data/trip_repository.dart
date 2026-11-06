import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/trip_record.dart';
import '../domain/trip_route_point.dart';
import 'trip_session_snapshot.dart';

/// Transactional storage for completed fares. Never use prefs for critical trips.
class TripRepository {
  TripRepository({Database? database, String? databasePath})
      : _database = database, _customDatabasePath = databasePath;
  Database? _database;
  final String? _customDatabasePath;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final databasePath = _customDatabasePath ??
        path.join(await getDatabasesPath(), 'ttx_aataximeter_v1.db');
    _database = await openDatabase(
      databasePath, version: 3,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE trips (
          id TEXT PRIMARY KEY,
          started_at TEXT NOT NULL,
          total_fare REAL NOT NULL,
          distance_km REAL NOT NULL,
          payload TEXT NOT NULL
        )''');
        await db.execute(
          'CREATE INDEX trips_started_at_idx ON trips(started_at DESC)');
        await _createSessionTable(db);
        await _createRouteTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSessionTable(db);
        if (oldVersion < 3) await _createRouteTable(db);
      },
    );
    return _database!;
  }

  static Future<void> _createSessionTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS active_trip (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      payload TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
  }

  static Future<void> _createRouteTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS active_trip_route (
      sequence INTEGER PRIMARY KEY,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      recorded_at TEXT NOT NULL,
      accuracy_meters REAL NOT NULL,
      speed_kmh REAL NOT NULL,
      segment INTEGER NOT NULL
    )''');
  }

  static Map<String, Object?> _routeRow(int sequence, TripRoutePoint point) =>
      {
        'sequence': sequence,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'recorded_at': point.recordedAt.toIso8601String(),
        'accuracy_meters': point.accuracyMeters,
        'speed_kmh': point.speedKmh,
        'segment': point.segment,
      };

  static TripRoutePoint _decodeRouteRow(Map<String, Object?> row) =>
      TripRoutePoint.fromJson({
        'lat': row['latitude'],
        'lon': row['longitude'],
        'at': row['recorded_at'],
        'accuracy': row['accuracy_meters'],
        'speed': row['speed_kmh'],
        'segment': row['segment'],
      });

  static Future<int> _routeCount(DatabaseExecutor txn) async {
    final rows = await txn.rawQuery(
      'SELECT COUNT(*) AS count, MAX(sequence) AS last FROM active_trip_route');
    final count = rows.first['count'] as int;
    final last = rows.first['last'] as int?;
    if (last != null && (last + 1 != count)) {
      throw const FormatException('Active trip GPS route contains gaps');
    }
    return count;
  }

  /// Older app builds kept all GPS points in active_trip.payload. A v2->v3
  /// schema migration intentionally leaves that payload untouched; the first
  /// v3 checkpoint adopts its points in the SAME transaction as the new
  /// lightweight header. Failure rolls back the entire conversion.
  static Future<void> _adoptLegacyActive(
    Transaction txn, String existing, String startedAt,
  ) async {
    final decoded = jsonDecode(existing);
    if (decoded is! Map || decoded['meter'] is! Map) {
      throw const FormatException('Unrecognized active-trip checkpoint');
    }
    final oldMeter = decoded['meter'] as Map;
    if (oldMeter['startedAt']?.toString() != startedAt) {
      throw StateError('Different active trip must not replace saved GPS');
    }
    if (decoded['routeStorage'] == 'sqlite-v3') return;
    final legacy = TripSessionSnapshot.decode(existing);
    if (legacy.routePoints.isNotEmpty) {
      final batch = txn.batch();
      for (var i = 0; i < legacy.routePoints.length; i++) {
        batch.insert('active_trip_route',
          _routeRow(i, legacy.routePoints[i]),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }

  /// Start a new session atomically, never mixing GPS data with a prior trip.
  /// This is used only after the UI confirms that no active trip is in use.
  Future<void> beginActive(TripSessionSnapshot snapshot) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query('active_trip', columns: ['id'],
        where: 'id = ?', whereArgs: [1], limit: 1);
      if (existing.isNotEmpty) {
        throw StateError('Không ghi đè chuyến chưa được lưu hoàn tất');
      }
      await txn.delete('active_trip_route');
      await txn.insert('active_trip', {
        'id': 1,
        'payload': snapshot.encodeSqliteHeader(routeCount: 0),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// One atomic write contains the current meter and ONLY NEW GPS points.
  /// Route indices are stable and INSERT OR IGNORE permits safe retries after
  /// queued writes fail. Gaps/stale states abort rather than truncate history.
  Future<void> saveActiveIncremental({
    required TripSessionSnapshot snapshot,
    required int routeStartIndex,
    required List<TripRoutePoint> appendedPoints,
  }) async {
    if (routeStartIndex < 0) {
      throw ArgumentError.value(routeStartIndex, 'routeStartIndex');
    }
    final startedAt = snapshot.meter['startedAt']?.toString();
    if (startedAt == null || startedAt.isEmpty) {
      throw const FormatException('Missing active-trip start time');
    }
    final expectedCount = routeStartIndex + appendedPoints.length;
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query('active_trip', columns: ['payload'],
        where: 'id = ?', whereArgs: [1], limit: 1);
      if (existing.isEmpty) {
        throw StateError('Active trip disappeared before GPS checkpoint');
      }
      await _adoptLegacyActive(
        txn, existing.first['payload'] as String, startedAt);
      final currentCount = await _routeCount(txn);
      if (routeStartIndex > currentCount || currentCount > expectedCount) {
        throw StateError('GPS checkpoint is stale or missing route samples');
      }
      if (appendedPoints.isNotEmpty) {
        final batch = txn.batch();
        for (var i = 0; i < appendedPoints.length; i++) {
          final point = appendedPoints[i];
          // Validate route samples before committing them to crash recovery.
          TripRoutePoint.fromJson(point.toJson());
          batch.insert('active_trip_route',
            _routeRow(routeStartIndex + i, point),
            conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        // One native SQLite batch, still enclosed by the transaction.
        await batch.commit(noResult: true);
      }
      final actualCount = await _routeCount(txn);
      if (actualCount != expectedCount) {
        throw StateError('GPS checkpoint route sequence is incomplete');
      }
      await txn.insert('active_trip', {
        'id': 1,
        'payload': snapshot.encodeSqliteHeader(routeCount: actualCount),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Compatibility for legacy tests/tools that still write full snapshots.
  /// Never leave orphaned route rows attached to a replacement checkpoint.
  Future<void> saveActive(String payload) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('active_trip_route');
      await txn.insert('active_trip', {
        'id': 1,
        'payload': payload,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Rehydrate the original snapshot format once on app restart. The UI and
  /// fare engine need no knowledge of the normalized SQLite route table.
  Future<String?> loadActive() async {
    final db = await _db;
    return db.transaction((txn) async {
      final rows = await txn.query('active_trip', columns: ['payload'],
        where: 'id = ?', whereArgs: [1], limit: 1);
      if (rows.isEmpty) return null;
      final payload = rows.first['payload'] as String;
      final decoded = jsonDecode(payload);
      if (decoded is! Map || decoded['routeStorage'] != 'sqlite-v3') {
        // Old snapshots retain their complete inline GPS route.
        return payload;
      }
      final expectedCount = decoded['routeCount'];
      if (expectedCount is! int || expectedCount < 0) {
        throw const FormatException('Missing persisted GPS route count');
      }
      final saved = await txn.query('active_trip_route',
        orderBy: 'sequence ASC');
      if (saved.length != expectedCount) {
        throw const FormatException('Persisted route count mismatch');
      }
      final points = <Map<String, dynamic>>[];
      for (var i = 0; i < saved.length; i++) {
        if (saved[i]['sequence'] != i) {
          throw const FormatException('GPS route ordering gap');
        }
        points.add(_decodeRouteRow(saved[i]).toJson());
      }
      final full = Map<String, dynamic>.from(decoded);
      full.remove('routeStorage');
      full.remove('routeCount');
      full['routePoints'] = points;
      return jsonEncode(full);
    });
  }

  Future<void> clearActive() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('active_trip_route');
      await txn.delete('active_trip', where: 'id = ?', whereArgs: [1]);
    });
  }

  /// A completed trip and deletion of its checkpoint commit together.
  /// On crash either the checkpoint or final receipt remains recoverable.
  Future<void> completeActive(TripRecord record) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('trips', _row(record),
        conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('active_trip_route');
      await txn.delete('active_trip', where: 'id = ?', whereArgs: [1]);
    });
  }

  static Map<String, Object?> _row(TripRecord t) => {
    'id': t.id,
    'started_at': t.receipt.startedAt.toIso8601String(),
    'total_fare': t.receipt.totalFare,
    'distance_km': t.receipt.distanceKm,
    'payload': t.encode(),
  };

  Future<void> initializeAndMigrate({
    SharedPreferencesAsync? legacyPreferences,
  }) async {
    final db = await _db;
    final prefs = legacyPreferences ?? SharedPreferencesAsync();
    final raw = await prefs.getString('ttx_history_v1');
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Legacy trip list malformed');
    }
    final records = decoded.whereType<Map>()
        .map((v) => TripRecord.fromJson(Map<String, dynamic>.from(v)))
        .toList(growable: false);
    await db.transaction((txn) async {
      for (final item in records) {
        await txn.insert('trips', _row(item),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    // Failure to remove legacy value is safe: migration is idempotent.
    await prefs.remove('ttx_history_v1');
  }

  Future<void> save(TripRecord record) async {
    final db = await _db;
    await db.transaction((txn) => txn.insert(
      'trips', _row(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    ));
  }

  Future<List<TripRecord>> listTrips() async {
    final db = await _db;
    final rows = await db.query('trips', orderBy: 'started_at DESC');
    return rows.map((row) =>
        TripRecord.decode(row['payload']! as String)).toList(growable: false);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('trips');
  }

  /// Create a consistent, single-file SQLite snapshot without touching the
  /// live database or its WAL. Never copy the live .db file while it is open:
  /// pending WAL frames could be missing from such a copy.
  ///
  /// The caller owns the returned temporary file and MUST remove it after
  /// exporting/cancelling. No import or overwrite operation is performed.
  Future<File> createVerifiedBackup({
    required Directory destinationDirectory,
  }) async {
    final db = await _db;
    await destinationDirectory.create(recursive: true);
    final filename = 'ttx-sqlite-backup-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.db';
    final file = File(path.join(destinationDirectory.path, filename));
    if (await file.exists()) {
      throw StateError('Backup target already exists');
    }
    try {
      // SQLite VACUUM INTO takes a transactionally consistent snapshot,
      // including data committed in the write-ahead log.
      await db.execute('VACUUM INTO ?', [file.path]);
      final backup = await openDatabase(
        file.path, readOnly: true, singleInstance: false);
      try {
        final check = await backup.rawQuery('PRAGMA integrity_check');
        if (check.length != 1 || check.single['integrity_check'] != 'ok') {
          throw const FormatException('SQLite backup integrity check failed');
        }
        final tables = await backup.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('trips', 'active_trip', 'active_trip_route')");
        if (tables.length != 3) {
          throw const FormatException('SQLite backup schema is incomplete');
        }
      } finally {
        await backup.close();
      }
      return file;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow; // No unsafe raw-file-copy fallback if VACUUM INTO fails.
    }
  }

  /// Preflight of an *external* SQLite backup. No writes are performed.
  static Future<TripBackupInspection> inspectBackupFile(File file) async {
    if (!await file.exists() || await file.length() == 0) {
      throw const FormatException('Tệp SQLite sao lưu trống hoặc không tồn tại');
    }
    final database = await openDatabase(
      file.path, readOnly: true, singleInstance: false);
    try {
      return _inspectData(database);
    } finally {
      await database.close();
    }
  }

  /// A consistent, read-only inventory of the currently installed data.
  /// For comparisons only: never changes or replaces existing trips.
  Future<TripBackupInspection> inspectCurrentData() async {
    final database = await _db;
    return database.transaction((txn) => _inspectData(txn));
  }

  static Future<TripBackupInspection> _inspectData(
      DatabaseExecutor reader) async {
    final integrity = await reader.rawQuery('PRAGMA integrity_check');
    if (integrity.length != 1 ||
        integrity.single['integrity_check'] != 'ok') {
      throw const FormatException('SQLite integrity_check không đạt');
    }
    final version = await reader.rawQuery('PRAGMA user_version');
    if (version.isEmpty || version.first['user_version'] != 3) {
      throw const FormatException('Chỉ hỗ trợ kiểm tra SQLite schema v3');
    }
    final tables = await reader.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('trips','active_trip','active_trip_route')");
    if (tables.length != 3) {
      throw const FormatException('Thiếu bảng dữ liệu TTX');
    }

    final completed = await reader.query('trips',
      columns: ['id', 'payload']);
    final digests = <String, String>{};
    for (final row in completed) {
      final id = row['id'];
      final payload = row['payload'];
      if (id is! String || id.isEmpty || payload is! String) {
        throw const FormatException('Hóa đơn SQLite thiếu mã hoặc nội dung');
      }
      final decoded = TripRecord.decode(payload);
      if (decoded.id != id || digests.containsKey(id)) {
        throw const FormatException('Mã hóa đơn SQLite không khớp');
      }
      digests[id] = sha256.convert(utf8.encode(payload)).toString();
    }

    final activeRows = await reader.query('active_trip',
      columns: ['payload']);
    if (activeRows.length > 1) {
      throw const FormatException('Có nhiều checkpoint đang hoạt động');
    }
    final route = await reader.query('active_trip_route',
      orderBy: 'sequence ASC');
    for (var index = 0; index < route.length; index++) {
      if (route[index]['sequence'] != index) {
        throw const FormatException('Dữ liệu GPS SQLite bị thiếu thứ tự');
      }
      // Reject malformed coordinates, timestamps and accuracy even if the
      // SQLite file and manifest hashes are otherwise structurally valid.
      _decodeRouteRow(route[index]);
    }
    if (activeRows.isEmpty) {
      if (route.isNotEmpty) {
        throw const FormatException('GPS không có chuyến đang hoạt động');
      }
      return TripBackupInspection(
        completedTripCount: digests.length,
        completedTripDigests: Map<String, String>.unmodifiable(digests),
        hasActiveTrip: false, activeRouteCount: 0);
    }
    final payload = activeRows.single['payload'];
    if (payload is! String) {
      throw const FormatException('Checkpoint thiếu dữ liệu');
    }
    final snapshot = TripSessionSnapshot.decode(payload);
    final header = jsonDecode(payload);
    if (header is! Map) {
      throw const FormatException('Checkpoint không hợp lệ');
    }
    final startedAt = snapshot.meter['startedAt']?.toString();
    if (header['routeStorage'] == 'sqlite-v3') {
      final expected = header['routeCount'];
      if (expected is! int || expected < 0 || expected != route.length) {
        throw const FormatException('Số điểm GPS checkpoint không khớp');
      }
    } else if (header['routeStorage'] == null) {
      if (route.isNotEmpty) {
        throw const FormatException('Checkpoint cũ có GPS journal bất thường');
      }
      return TripBackupInspection(
        completedTripCount: digests.length,
        completedTripDigests: Map<String, String>.unmodifiable(digests),
        hasActiveTrip: true,
        activeRouteCount: snapshot.routePoints.length,
        activeTripStartedAt: startedAt);
    } else {
      throw const FormatException('Kiểu lưu GPS không được hỗ trợ');
    }
    return TripBackupInspection(
      completedTripCount: digests.length,
      completedTripDigests: Map<String, String>.unmodifiable(digests),
      hasActiveTrip: true,
      activeRouteCount: route.length,
      activeTripStartedAt: startedAt);
  }

  Future<void> dispose() async {
    final db = _database;
    _database = null;
    if (db != null) await db.close();
  }
}

/// Verified read-only metadata. No restored data is applied to the app.
/// Receipt SHA-256 digests are internal comparison inputs; never display
/// raw trip IDs or customer information in the preflight UI.
class TripBackupInspection {
  const TripBackupInspection({
    required this.completedTripCount,
    required this.hasActiveTrip,
    required this.activeRouteCount,
    this.completedTripDigests = const {},
    this.activeTripStartedAt,
  });

  final int completedTripCount;
  final bool hasActiveTrip;
  final int activeRouteCount;
  final Map<String, String> completedTripDigests;
  final String? activeTripStartedAt;
}
