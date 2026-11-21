import 'package:sqflite/sqflite.dart';

import '../domain/traffic_sign.dart';
import 'traffic_sign_query_metrics.dart';

/// Read-only spatial queries; independent of taximeter/trip SQLite.
class TrafficSignRepository {
  TrafficSignRepository(this.database, {this.useRtree = true});

  final Database database;
  /// Some Android system SQLite builds do not compile the RTree extension.
  /// Use a read-only bbox scan on the original rows on those devices.
  /// Never alter the owner-supplied database to work around this capability.
  final bool useRtree;
  final TrafficSignQueryMetrics queryMetrics = TrafficSignQueryMetrics();
  static const int maxVisibleItems = 320;

  Future<TrafficSign?> byId(int signId) async {
    final rows = await database.query(
      'traffic_signs', where: 'sign_id = ?', whereArgs: [signId], limit: 1,
    );
    return rows.isEmpty ? null : TrafficSign.fromRow(rows.first);
  }

  Future<List<int>> availableTypeCodes() async {
    final rows = await database.rawQuery(
      'SELECT DISTINCT sign_type_code FROM traffic_signs '
      'ORDER BY sign_type_code',
    );
    return rows.map((r) => r['sign_type_code'] as int).toList(growable: false);
  }

  /// Never allocates 151k Dart/Flutter markers. At high density, SQLite
  /// aggregates by grid cell and returns at most ~256 map points.
  Future<SignViewportResult> viewport(
      SignViewport bounds, TrafficSignFilter filter) async {
    if (!filter.enabled || !bounds.isValid) return SignViewportResult.empty;
    final stopwatch = Stopwatch()..start();
    try {
      final value = await _queryViewport(bounds, filter);
      queryMetrics.record(stopwatch.elapsed, succeeded: true);
      return value;
    } catch (_) {
      queryMetrics.record(stopwatch.elapsed, succeeded: false);
      rethrow;
    }
  }

  Future<SignViewportResult> _queryViewport(
      SignViewport bounds, TrafficSignFilter filter) async {
    // The same verified 151,228-row source supports both query plans.
    // Only SQL's FROM/predicate changes. Point coordinates, filtering,
    // aggregation, sign IDs and safety status remain identical.
    final args = <Object?>[
      if (useRtree) ...[
        bounds.east, bounds.west, bounds.north, bounds.south,
      ],
      bounds.west, bounds.east, bounds.south, bounds.north,
    ];
    final conditions = <String>[
      if (useRtree) ...[
        'r.min_longitude <= ? AND r.max_longitude >= ?',
        'r.min_latitude <= ? AND r.max_latitude >= ?',
      ],
      's.longitude BETWEEN ? AND ?',
      's.latitude BETWEEN ? AND ?',
    ];
    if (filter.speedOnly) {
      // Owner-confirmed raw speed signs only; other sign types may have
      // non-zero raw values which do NOT represent posted speed.
      conditions.add('s.sign_type_code = 1 AND s.value_raw > 0');
    }
    if (filter.typeCode != null) {
      conditions.add('s.sign_type_code = ?');
      args.add(filter.typeCode);
    }
    final from = (useRtree
            ? 'FROM traffic_sign_rtree AS r '
                'JOIN traffic_signs AS s ON s.sign_id = r.sign_id '
            : 'FROM traffic_signs AS s ') +
        'WHERE ${conditions.join(' AND ')}';
    final countRows = await database.rawQuery(
      'SELECT COUNT(*) AS total $from', args,
    );
    final total = (countRows.first['total'] as num).toInt();
    if (total == 0) return SignViewportResult.empty;

    if (total <= maxVisibleItems) {
      final rows = await database.rawQuery(
        'SELECT s.sign_id, s.longitude, s.latitude, '
        's.sign_type_code, s.value_raw, s.speed_kmh_inferred '
        '$from ORDER BY s.sign_id', args,
      );
      return SignViewportResult(
        total: total,
        items: rows.map((r) => SignMapItem(
          signId: r['sign_id'] as int,
          longitude: (r['longitude'] as num).toDouble(),
          latitude: (r['latitude'] as num).toDouble(),
          count: 1,
          speedKmhInferred: r['speed_kmh_inferred'] as int?,
          signTypeCode: r['sign_type_code'] as int,
          valueRaw: r['value_raw'] as int,
        )).toList(growable: false),
      );
    }

    // Fixed number of grid buckets in the viewport, not a LIMIT on raw
    // records. All matching database rows are accounted for in cluster sums.
    final lonStep = ((bounds.east - bounds.west) / 15).clamp(0.000001, 360.0);
    final latStep = ((bounds.north - bounds.south) / 15).clamp(0.000001, 180.0);
    final grouped = await database.rawQuery(
      'SELECT MIN(s.sign_id) AS sign_id, '
      'AVG(s.longitude) AS longitude, AVG(s.latitude) AS latitude, '
      'COUNT(*) AS total, '
      'CASE WHEN COUNT(*) = 1 THEN MAX(s.speed_kmh_inferred) '
      'ELSE NULL END AS speed_kmh_inferred, '
      'CASE WHEN COUNT(*) = 1 THEN MIN(s.sign_type_code) '
      'ELSE NULL END AS sign_type_code, '
      'CASE WHEN COUNT(*) = 1 THEN MIN(s.value_raw) '
      'ELSE NULL END AS value_raw '
      '$from GROUP BY '
      'CAST((s.longitude - ?) / ? AS INTEGER), '
      'CAST((s.latitude - ?) / ? AS INTEGER)',
      [...args, bounds.west, lonStep, bounds.south, latStep],
    );
    final items = grouped.map((r) => SignMapItem(
      signId: r['sign_id'] as int,
      longitude: (r['longitude'] as num).toDouble(),
      latitude: (r['latitude'] as num).toDouble(),
      count: (r['total'] as num).toInt(),
      speedKmhInferred: r['speed_kmh_inferred'] as int?,
      signTypeCode: r['sign_type_code'] as int?,
      valueRaw: r['value_raw'] as int?,
    )).toList(growable: false);

    // RTree GROUP BY is not a silent display truncation.
    if (items.length > maxVisibleItems ||
        items.fold<int>(0, (n, item) => n + item.count) != total) {
      throw StateError('Traffic sign clustering failed count invariant');
    }
    return SignViewportResult(total: total, items: items);
  }
}
