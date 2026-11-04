import 'dart:math' as math;

/// Original, independently implemented calculation engine for TTX AATaximeter.
/// Example tariff values are NOT extracted/verified defaults from the APK.
enum MeterStatus { idle, running, paused, finished }

/// One cumulative pricing band, ending at [upToKm] measured from trip start.
/// A null upper bound means the final unlimited distance band.
class FareTier {
  const FareTier({required this.upToKm, required this.ratePerKm});
  final double? upToKm;
  final double ratePerKm;
  Map<String, dynamic> toJson() => {
    'upToKm': upToKm, 'ratePerKm': ratePerKm,
  };
  factory FareTier.fromJson(Map<String, dynamic> map) => FareTier(
    upToKm: (map['upToKm'] as num?)?.toDouble(),
    ratePerKm: (map['ratePerKm'] as num).toDouble(),
  );
}

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
    this.fareTiers,
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
  final List<FareTier>? fareTiers;
  bool get hasTieredFare => fareTiers != null;

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
    final bands = fareTiers;
    if (bands != null) {
      if (bands.isEmpty || bands.length > 12) {
        throw ArgumentError('Cần từ 1 đến 12 bậc giá');
      }
      var previous = baseDistanceKm;
      for (var i = 0; i < bands.length; i++) {
        final band = bands[i];
        if (!band.ratePerKm.isFinite || band.ratePerKm < 0) {
          throw ArgumentError('Đơn giá từng bậc không hợp lệ');
        }
        final end = band.upToKm;
        if (i == bands.length - 1) {
          if (end != null) throw ArgumentError('Bậc cuối phải không giới hạn');
        } else {
          if (end == null || !end.isFinite || end <= previous) {
            throw ArgumentError('Các ngưỡng km phải tăng dần');
          }
          previous = end;
        }
      }
    }
  }

  /// Cumulative progressive charge: the next tier applies only to km inside
  /// that tier, not retroactively to the entire trip.
  double distanceChargeForKm(double km) {
    if (!km.isFinite || km < 0) throw ArgumentError('Số km không hợp lệ');
    final distance = math.max(0.0, km - baseDistanceKm);
    if (fareTiers == null) {
      final standard = math.max(0.0,
          longDistanceThresholdKm - baseDistanceKm);
      return math.min(distance, standard) * perKmRate +
          math.max(0.0, distance - standard) * longDistancePerKmRate;
    }
    var previousKm = baseDistanceKm;
    var price = 0.0;
    for (final band in fareTiers!) {
      final boundary = band.upToKm ?? km;
      final inBand = math.max(0.0, math.min(km, boundary) - previousKm);
      price += inBand * band.ratePerKm;
      if (band.upToKm == null || km <= boundary) break;
      previousKm = boundary;
    }
    return price;
  }

  List<FareTier> get effectiveFareTiers => fareTiers ??
      <FareTier>[
        FareTier(upToKm: longDistanceThresholdKm, ratePerKm: perKmRate),
        FareTier(upToKm: null, ratePerKm: longDistancePerKmRate),
      ];


  TariffConfig copyWith({
    double? baseFare, double? baseDistanceKm, double? perKmRate,
    double? longDistanceThresholdKm, double? longDistancePerKmRate,
    double? waitingFeePerHour, double? waitingSpeedThresholdKmh,
    double? speedLimitKmh, double? gpsMaxAccuracyMeters,
    double? gpsCalibrationMultiplier, bool? roundToThousands, String? name,
    List<FareTier>? fareTiers,
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
        fareTiers: fareTiers ?? this.fareTiers,
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
  bool _interrupted = false;
  bool get requiresManualResume => _interrupted;

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
    _interrupted = false;
    status = MeterStatus.running;
  }

  void tick(DateTime now) {
    if (status != MeterStatus.running && status != MeterStatus.paused) return;
    if (_interrupted) {
      // Never bill wall-clock time without reliable location/service evidence.
      _lastTick = now;
      return;
    }
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
    final now = at ?? DateTime.now();
    if (!_interrupted) tick(now);
    _interrupted = false;
    _lastTick = now;
    status = MeterStatus.running;
    _lastFix = null; // New baseline: do not invent distance during the gap.
    speedKmh = 0;
  }

  /// Pause and stop all metering when the app loses a trustworthy clock/GPS
  /// lifecycle (e.g., background without a foreground location service).
  /// This differs from the driver's manual pause which still counts waiting.
  void suspendForInterruption({DateTime? at}) {
    if (status != MeterStatus.running && status != MeterStatus.paused) return;
    final now = at ?? DateTime.now();
    if (!_interrupted) tick(now);
    _interrupted = true;
    status = MeterStatus.paused;
    speedKmh = 0;
    _lastFix = null;
    _lastTick = now;
  }

  /// Serializable snapshot for crash recovery. Tariff and trip metadata are
  /// stored with it by TripSessionSnapshot.
  Map<String, dynamic> exportSnapshot() {
    if (status != MeterStatus.running && status != MeterStatus.paused) {
      throw StateError('Only active trips can be checkpointed');
    }
    return {
      'version': 1,
      'status': status.name,
      'startedAt': startedAt?.toIso8601String(),
      'distanceMeters': distanceMeters,
      'elapsedSeconds': elapsedSeconds,
      'waitingSeconds': waitingSeconds,
      'speedKmh': speedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'tollFee': tollFee,
      'surcharge': surcharge,
      'discount': discount,
      'flatFare': flatFare,
      'interrupted': _interrupted,
    };
  }

  /// Restore as suspended/paused: never charge the app-off interval.
  /// The driver must deliberately resume and reestablish a GPS baseline.
  factory TaximeterEngine.fromSnapshot({
    required TariffConfig tariff,
    required Map<String, dynamic> snapshot,
    DateTime? recoveredAt,
  }) {
    final version = snapshot['version'];
    if (version != 1) throw const FormatException('Unknown trip snapshot version');
    final original = snapshot['status']?.toString();
    if (original != 'running' && original != 'paused') {
      throw const FormatException('No in-progress trip in snapshot');
    }
    final startedAt = DateTime.tryParse(snapshot['startedAt']?.toString() ?? '');
    if (startedAt == null) throw const FormatException('Missing trip start time');
    double requiredNumber(String field) {
      final n = snapshot[field];
      if (n is! num || !n.toDouble().isFinite || n < 0) {
        throw FormatException('Invalid snapshot field: $field');
      }
      return n.toDouble();
    }

    final distance = requiredNumber('distanceMeters');
    final elapsed = requiredNumber('elapsedSeconds');
    final waiting = requiredNumber('waitingSeconds');
    if (waiting > elapsed) throw const FormatException('Waiting exceeds trip duration');
    final maxSpeed = requiredNumber('maxSpeedKmh');
    final toll = requiredNumber('tollFee');
    final extra = requiredNumber('surcharge');
    final discount = requiredNumber('discount');
    final fixed = snapshot['flatFare'];
    if (fixed != null && (fixed is! num || !fixed.toDouble().isFinite || fixed < 0)) {
      throw const FormatException('Invalid fixed fare');
    }

    final restored = TaximeterEngine(tariff: tariff)
      ..startedAt = startedAt
      .._lastTick = recoveredAt ?? DateTime.now()
      .._lastFix = null
      .._interrupted = true
      ..status = MeterStatus.paused
      ..distanceMeters = distance
      ..elapsedSeconds = elapsed.toInt()
      ..waitingSeconds = waiting.toInt()
      ..speedKmh = 0
      ..maxSpeedKmh = maxSpeed
      ..tollFee = toll
      ..surcharge = extra
      ..discount = discount
      ..flatFare = fixed == null ? null : (fixed as num).toDouble();
    return restored;
  }

  /// Returns true only for valid telemetry actually accepted by the meter.
  /// A rejected outlier must not refresh the UI's GPS freshness watchdog.
  bool acceptGps(GpsFix fix) {
    if (!fix.latitude.isFinite || !fix.longitude.isFinite ||
        fix.latitude.abs() > 90 || fix.longitude.abs() > 180 ||
        !fix.accuracyMeters.isFinite || fix.accuracyMeters < 0 ||
        fix.accuracyMeters > _tariff.gpsMaxAccuracyMeters ||
        !fix.speedKmh.isFinite || fix.speedKmh < 0) return false;

    if (status != MeterStatus.running) {
      speedKmh = fix.speedKmh;
      maxSpeedKmh = math.max(maxSpeedKmh, speedKmh);
      return true;
    }
    final before = _lastFix;
    if (before == null) {
      _lastFix = fix;
      speedKmh = fix.speedKmh;
      maxSpeedKmh = math.max(maxSpeedKmh, speedKmh);
      return true;
    }
    if (!fix.timestamp.isAfter(before.timestamp)) return false;
    final seconds =
        fix.timestamp.difference(before.timestamp).inMilliseconds / 1000;
    final meters = _haversine(before, fix);
    final plausibleMax = math.max(25.0, seconds * 65.0);
    // Reject GPS jumps without replacing the last known-good fix.
    if (meters > plausibleMax) return false;
    _lastFix = fix;
    speedKmh = fix.speedKmh;
    maxSpeedKmh = math.max(maxSpeedKmh, speedKmh);
    final noiseFloor = math.max(
      3.0, math.max(before.accuracyMeters, fix.accuracyMeters) * 0.5,
    );
    if (meters > noiseFloor) {
      distanceMeters += meters * _tariff.gpsCalibrationMultiplier;
    }
    return true;
  }

  /// Advance the internal monotonic meter tick reference without charging
  /// waiting time or inventing distance during an untrusted GPS interval.
  void skipUntrustedInterval(DateTime at) {
    if ((status != MeterStatus.running && status != MeterStatus.paused) ||
        _interrupted) return;
    if (_lastTick == null || at.isBefore(_lastTick!)) return;
    _lastTick = at;
    _lastFix = null;
    speedKmh = 0;
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
    return _tariff.distanceChargeForKm(distanceKm);
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
    _interrupted = false;
  }
}
