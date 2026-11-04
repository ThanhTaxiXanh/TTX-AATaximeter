import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/trip_record.dart';

/// Transactional storage for completed fares. Never use prefs for critical trips.
class TripRepository {
  TripRepository({Database? database}) : _database = database;
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'ttx_aataximeter_v1.db'), version: 1,
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
      },
    );
    return _database!;
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

  Future<void> dispose() async {
    final db = _database;
    _database = null;
    if (db != null) await db.close();
  }
}
