import 'dart:math' as math;

/// Original, independently implemented calculation engine for TTX AATaximeter.
/// Example tariff values are NOT extracted/verified defaults from the APK.
enum MeterStatus { idle, running, paused, finished }

class TariffConfig {
  const TariffConfig({
    required this.baseFare,
    required this.baseDistanceKm,
    required this.perKmRate,
    required this.longDistanceThresholdKm,
    required this.longDistancePerKmRate,
    required this.waitingFeePerHour,
    this.waitingSpeedThresholdKmh = 5,
    this.speedLimitKmh = 80,
    this.gpsMaxAccuracyMeters = 30,
    this.gpsCalibrationMultiplier = 1,
    this.roundToThousands = true,
    this.name = 'Tùy chỉnh',
  });

  // Observed in the supplied 2026-11-04 reference videos.
  // This example preset is not a legally certified taxi tariff.
  factory TariffConfig.demo() => const TariffConfig(
        name: 'Taxi Đô Thị 4 Chỗ (mẫu tham khảo)',
        baseFare: 12000,
        baseDistanceKm: 0.5,
        perKmRate: 14500,
        longDistanceThresholdKm: 30,
        longDistancePerKmRate: 12000,
        waitingFeePerHour: 30000,
        waitingSpeedThresholdKmh: 5,
        speedLimitKmh: 80,
        gpsMaxAccuracyMeters: 35,
      );

  final String name;
  final double baseFare;
  final double baseDistanceKm;
  final double perKmRate;
  final double longDistanceThresholdKm;
  final double longDistancePerKmRate;
  final double waitingFeePerHour;
  final double waitingSpeedThresholdKmh;
  final double speedLimitKmh;
  final double gpsMaxAccuracyMeters;
  final double gpsCalibrationMultiplier;
  final bool roundToThousands;

  void validate() {
    final values = [
      baseFare, baseDistanceKm, perKmRate, longDistanceThresholdKm,
      longDistancePerKmRate, waitingFeePerHour, waitingSpeedThresholdKmh,
      speedLimitKmh, gpsMaxAccuracyMeters, gpsCalibrationMultiplier,
    ];
    if (values.any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Đơn giá hoặc cấu hình không hợp lệ');
    }
    if (longDistanceThresholdKm < baseDistanceKm ||
        gpsMaxAccuracyMeters == 0 || gpsCalibrationMultiplier == 0) {
      throw ArgumentError('Sai ngưỡng khoảng cách hoặc độ chính xác GPS');
    }
  }

  TariffConfig copyWith({
    double? baseFare, double? baseDistanceKm, double? perKmRate,
    double? longDistanceThresholdKm, double? longDistancePerKmRate,
    double? waitingFeePerHour, double? waitingSpeedThresholdKmh,
    double? speedLimitKmh, double? gpsMaxAccuracyMeters,
    double? gpsCalibrationMultiplier, bool? roundToThousands, String? name,
  }) => TariffConfig(
        baseFare: baseFare ?? this.baseFare,
        baseDistanceKm: baseDistanceKm ?? this.baseDistanceKm,
        perKmRate: perKmRate ?? this.perKmRate,
        longDistanceThresholdKm:
            longDistanceThresholdKm ?? this.longDistanceThresholdKm,
        longDistancePerKmRate:
            longDistancePerKmRate ?? this.longDistancePerKmRate,
        waitingFeePerHour: waitingFeePerHour ?? this.waitingFeePerHour,
        waitingSpeedThresholdKmh:
            waitingSpeedThresholdKmh ?? this.waitingSpeedThresholdKmh,
        speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
        gpsMaxAccuracyMeters: gpsMaxAccuracyMeters ?? this.gpsMaxAccuracyMeters,
        gpsCalibrationMultiplier:
            gpsCalibrationMultiplier ?? this.gpsCalibrationMultiplier,
        roundToThousands: roundToThousands ?? this.roundToThousands,
        name: name ?? this.name,
      );
}

class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedKmh,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedKmh;
  final DateTime timestamp;
}

class TripReceipt {
  const TripReceipt({
    required this.startedAt,
    required this.endedAt,
    required this.distanceKm,
    required this.durationSeconds,
    required this.waitingSeconds,
    required this.baseFare,
    required this.distanceFare,
    required this.waitingFare,
    required this.tollFee,
    required this.surcharge,
    required this.discount,
    required this.totalFare,
    required this.isFlatFare,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceKm;
  final int durationSeconds;
  final int waitingSeconds;
  final double baseFare, distanceFare, waitingFare;
  final double tollFee, surcharge, discount, totalFare;
  final bool isFlatFare;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        'waitingSeconds': waitingSeconds,
        'baseFare': baseFare,
        'distanceFare': distanceFare,
        'waitingFare': waitingFare,
        'tollFee': tollFee,
        'surcharge': surcharge,
        'discount': discount,
        'totalFare': totalFare,
        'isFlatFare': isFlatFare,
      };
}

class TaximeterEngine {
  TaximeterEngine({required TariffConfig tariff}) : _tariff = tariff {
    tariff.validate();
  }

  TariffConfig _tariff;
  TariffConfig get tariff => _tariff;
  MeterStatus status = MeterStatus.idle;
  DateTime? startedAt;
  DateTime? _lastTick;
  GpsFix? _lastFix;
  double distanceMeters = 0;
  int elapsedSeconds = 0;
  int waitingSeconds = 0;
  double speedKmh = 0;
  double maxSpeedKmh = 0;
  double tollFee = 0;
  double surcharge = 0;
  double discount = 0;
  double? flatFare;

  double get distanceKm => distanceMeters / 1000;
  bool get isOverSpeedLimit => speedKmh > _tariff.speedLimitKmh;

  void updateTariff(TariffConfig next) {
    if (status == MeterStatus.running || status == MeterStatus.paused) {
      throw StateError('Không đổi biểu giá trong chuyến');
    }
    next.validate();
    _tariff = next;
  }

  void start({DateTime? at, double? fixedFare}) {
    if (status != MeterStatus.idle) {
      throw StateError('Chỉ bắt đầu từ trạng thái chờ');
    }
    if (fixedFare != null && (!fixedFare.isFinite || fixedFare < 0)) {
      throw ArgumentError('Giá bao không hợp lệ');
    }
    startedAt = at ?? DateTime.now();
    _lastTick = startedAt;
    _lastFix = null;
    flatFare = fixedFare;
    status = MeterStatus.running;
  }

  void tick(DateTime now) {
    if (status != MeterStatus.running && status != MeterStatus.paused) return;
    final previous = _lastTick;
    if (previous == null || now.isBefore(previous)) return;
    final wholeSeconds = now.difference(previous).inSeconds;
    if (wholeSeconds <= 0) return;
    _lastTick = previous.add(Duration(seconds: wholeSeconds));
    elapsedSeconds += wholeSeconds;
    if (status == MeterStatus.paused ||
        speedKmh < _tariff.waitingSpeedThresholdKmh) {
      waitingSeconds += wholeSeconds;
    }
  }

  void pause({DateTime? at}) {
    if (status != MeterStatus.running) return;
    tick(at ?? DateTime.now());
    status = MeterStatus.paused;
  }

  void resume({DateTime? at}) {
    if (status != MeterStatus.paused) return;
    tick(at ?? DateTime.now());
    status = MeterStatus.running;
    _lastFix = null; // Prevent adding a jump during the pause.
  }

  void acceptGps(GpsFix fix) {
    if (!fix.latitude.isFinite || !fix.longitude.isFinite ||
        fix.latitude.abs() > 90 || fix.longitude.abs() > 180 ||
        !fix.accuracyMeters.isFinite || fix.accuracyMeters < 0 ||
        fix.accuracyMeters > _tariff.gpsMaxAccuracyMeters ||
        !fix.speedKmh.isFinite) return;

    speedKmh = math.max(0, fix.speedKmh);
    maxSpeedKmh = math.max(maxSpeedKmh, speedKmh);
    if (status != MeterStatus.running) return;
    final before = _lastFix;
    if (before == null) {
      _lastFix = fix;
      return;
    }
    if (!fix.timestamp.isAfter(before.timestamp)) return;
    final seconds = fix.timestamp.difference(before.timestamp).inMilliseconds / 1000;
    final meters = _haversine(before, fix);
    final plausibleMax = math.max(25.0, seconds * 65.0);
    // Reject GPS jumps without replacing the last known-good fix.
    if (meters > plausibleMax) return;
    _lastFix = fix;
    final noiseFloor = math.max(
      3.0, math.max(before.accuracyMeters, fix.accuracyMeters) * 0.5,
    );
    if (meters > noiseFloor) {
      distanceMeters += meters * _tariff.gpsCalibrationMultiplier;
    }
  }

  static double _haversine(GpsFix a, GpsFix b) {
    const radius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * radius * math.atan2(math.sqrt(h), math.sqrt(math.max(0, 1 - h)));
  }

  double get baseFare => status == MeterStatus.idle
      ? 0 : (flatFare ?? _tariff.baseFare);

  double get distanceFare {
    if (status == MeterStatus.idle || flatFare != null) return 0;
    final covered = math.max(0.0, distanceKm - _tariff.baseDistanceKm);
    final standardDistance = math.max(0.0,
        _tariff.longDistanceThresholdKm - _tariff.baseDistanceKm);
    return math.min(covered, standardDistance) * _tariff.perKmRate +
        math.max(0.0, covered - standardDistance) *
            _tariff.longDistancePerKmRate;
  }

  double get waitingFare => status == MeterStatus.idle || flatFare != null
      ? 0 : (waitingSeconds / 3600) * _tariff.waitingFeePerHour;

  double get rawFare => status == MeterStatus.idle
      ? 0
      : math.max(0.0,
          baseFare + distanceFare + waitingFare + tollFee + surcharge - discount);

  double get totalFare {
    final value = rawFare;
    if (flatFare != null || !_tariff.roundToThousands) return value;
    return ((value + 500) / 1000).floorToDouble() * 1000;
  }

  void addToll(double amount) {
    if (status != MeterStatus.running && status != MeterStatus.paused) return;
    if (!amount.isFinite || amount < 0) throw ArgumentError('Phí BOT không hợp lệ');
    tollFee += amount;
  }

  void setAdjustments({double? surchargeFee, double? discountFee}) {
    for (final value in [surchargeFee, discountFee]) {
      if (value != null && (!value.isFinite || value < 0)) {
        throw ArgumentError('Phí/giảm giá không hợp lệ');
      }
    }
    if (surchargeFee != null) surcharge = surchargeFee;
    if (discountFee != null) discount = discountFee;
  }

  TripReceipt finish({DateTime? at}) {
    if (status != MeterStatus.running && status != MeterStatus.paused) {
      throw StateError('Chưa có chuyến đang chạy');
    }
    final endedAt = at ?? DateTime.now();
    tick(endedAt);
    status = MeterStatus.finished;
    return TripReceipt(
      startedAt: startedAt!, endedAt: endedAt,
      distanceKm: distanceKm, durationSeconds: elapsedSeconds,
      waitingSeconds: waitingSeconds, baseFare: baseFare,
      distanceFare: distanceFare, waitingFare: waitingFare,
      tollFee: tollFee, surcharge: surcharge, discount: discount,
      totalFare: totalFare, isFlatFare: flatFare != null,
    );
  }

  void reset() {
    status = MeterStatus.idle;
    startedAt = null;
    _lastTick = null;
    _lastFix = null;
    distanceMeters = 0;
    elapsedSeconds = 0;
    waitingSeconds = 0;
    speedKmh = 0;
    maxSpeedKmh = 0;
    tollFee = 0;
    surcharge = 0;
    discount = 0;
    flatFare = null;
  }
}
