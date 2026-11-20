/// Display-only, unverified records from owner-provided geographic datasets.
class TrafficSign {
  const TrafficSign({
    required this.signId,
    required this.longitude,
    required this.latitude,
    required this.signTypeCode,
    required this.directionRaw,
    required this.valueRaw,
    required this.speedKmhInferred,
    required this.sourceDataset,
    required this.verificationStatus,
  });

  final int signId;
  final double longitude, latitude;
  final int signTypeCode, directionRaw, valueRaw;
  final int? speedKmhInferred;
  final String sourceDataset, verificationStatus;

  factory TrafficSign.fromRow(Map<String, Object?> row) => TrafficSign(
    signId: row['sign_id'] as int,
    longitude: (row['longitude'] as num).toDouble(),
    latitude: (row['latitude'] as num).toDouble(),
    signTypeCode: row['sign_type_code'] as int,
    directionRaw: row['direction_raw'] as int,
    valueRaw: row['value_raw'] as int,
    speedKmhInferred: row['speed_kmh_inferred'] as int?,
    sourceDataset: row['source_dataset'] as String,
    verificationStatus: row['verification_status'] as String,
  );
}

/// Raw values are never converted into legal limits or sign directions.
class TrafficSignFilter {
  const TrafficSignFilter({
    this.enabled = false,
    this.speedOnly = false,
    this.typeCode,
  });

  final bool enabled, speedOnly;
  final int? typeCode;

  TrafficSignFilter copyWith({
    bool? enabled,
    bool? speedOnly,
    int? typeCode,
    bool clearType = false,
  }) => TrafficSignFilter(
    enabled: enabled ?? this.enabled,
    speedOnly: speedOnly ?? this.speedOnly,
    typeCode: clearType ? null : (typeCode ?? this.typeCode),
  );
}

class SignViewport {
  const SignViewport({
    required this.west, required this.south,
    required this.east, required this.north,
  });

  final double west, south, east, north;

  bool get isValid => west.isFinite && east.isFinite &&
      south.isFinite && north.isFinite &&
      west >= -180 && east <= 180 && west <= east &&
      south >= -90 && north <= 90 && south <= north;
  
  /// Pad the visible region to avoid a SQL request on each small GPS move.
  SignViewport expanded([double fraction = 0.25]) {
    if (!isValid || !fraction.isFinite || fraction < 0) return this;
    final dx = (east - west) * fraction;
    final dy = (north - south) * fraction;
    return SignViewport(
      west: (west - dx).clamp(-180.0, 180.0).toDouble(),
      east: (east + dx).clamp(-180.0, 180.0).toDouble(),
      south: (south - dy).clamp(-90.0, 90.0).toDouble(),
      north: (north + dy).clamp(-90.0, 90.0).toDouble(),
    );
  }

  bool contains(SignViewport other) =>
      isValid && other.isValid &&
      west <= other.west && east >= other.east &&
      south <= other.south && north >= other.north;

}

/// A single sign or a database-side spatial aggregate.
class SignMapItem {
  const SignMapItem({
    required this.signId,
    required this.longitude,
    required this.latitude,
    required this.count,
    this.speedKmhInferred,
  });

  final int signId, count;
  final double longitude, latitude;
  final int? speedKmhInferred;

  bool get isCluster => count > 1;
}

class SignViewportResult {
  const SignViewportResult({required this.total, required this.items});

  final int total;
  final List<SignMapItem> items;

  static const empty = SignViewportResult(total: 0, items: []);
}
