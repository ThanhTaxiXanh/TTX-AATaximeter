import 'dart:convert';
import '../core/taximeter_engine.dart';

/// Configuration only. Completed fares live in SQLite.
class TariffCodec {
  static String encode(TariffConfig t) => jsonEncode({
    'version': 1,
    'name': t.name,
    'baseFare': t.baseFare,
    'baseDistanceKm': t.baseDistanceKm,
    'perKmRate': t.perKmRate,
    'longDistanceThresholdKm': t.longDistanceThresholdKm,
    'longDistancePerKmRate': t.longDistancePerKmRate,
    'waitingFeePerHour': t.waitingFeePerHour,
    'waitingSpeedThresholdKmh': t.waitingSpeedThresholdKmh,
    'waitingGraceMinutes': t.waitingGraceMinutes,
    'speedLimitKmh': t.speedLimitKmh,
    'gpsMaxAccuracyMeters': t.gpsMaxAccuracyMeters,
    'gpsCalibrationMultiplier': t.gpsCalibrationMultiplier,
    'roundToThousands': t.roundToThousands,
    'fareTiers': t.fareTiers?.map((t) => t.toJson()).toList(),
  });

  static TariffConfig decode(String raw) {
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final original = TariffConfig.demo();
    double value(String name, double fallback) {
      final n = data[name];
      if (n is num) return n.toDouble();
      return double.tryParse(n?.toString() ?? '') ?? fallback;
    }
    final config = TariffConfig(
      name: data['name']?.toString() ?? original.name,
      baseFare: value('baseFare', original.baseFare),
      baseDistanceKm: value('baseDistanceKm', original.baseDistanceKm),
      perKmRate: value('perKmRate', original.perKmRate),
      longDistanceThresholdKm:
          value('longDistanceThresholdKm', original.longDistanceThresholdKm),
      longDistancePerKmRate:
          value('longDistancePerKmRate', original.longDistancePerKmRate),
      waitingFeePerHour:
          value('waitingFeePerHour', original.waitingFeePerHour),
      waitingSpeedThresholdKmh:
          value('waitingSpeedThresholdKmh', original.waitingSpeedThresholdKmh),
      waitingGraceMinutes:
          value('waitingGraceMinutes', original.waitingGraceMinutes),
      speedLimitKmh: value('speedLimitKmh', original.speedLimitKmh),
      gpsMaxAccuracyMeters:
          value('gpsMaxAccuracyMeters', original.gpsMaxAccuracyMeters),
      gpsCalibrationMultiplier: value(
          'gpsCalibrationMultiplier', original.gpsCalibrationMultiplier),
      roundToThousands:
          data['roundToThousands'] is bool
              ? data['roundToThousands'] as bool
              : original.roundToThousands,
      fareTiers: data['fareTiers'] is List
          ? (data['fareTiers'] as List).map((v) =>
              FareTier.fromJson(Map<String, dynamic>.from(v as Map))).toList()
          : null,
    );
    config.validate();
    return config;
  }
}
