import 'dart:convert';
import '../core/taximeter_engine.dart';
import '../data/tariff_codec.dart';
import 'trip_route_point.dart';

enum PaymentMethod {
  cash, bankTransfer, card;
  String get label => switch (this) {
    cash => 'Tiền mặt',
    bankTransfer => 'Chuyển khoản',
    card => 'Thẻ',
  };
  static PaymentMethod fromCode(String? code) =>
      PaymentMethod.values.firstWhere((x) => x.name == code,
          orElse: () => PaymentMethod.cash);
}

/// Immutable completed trip; price is frozen at the time of completion.
class TripRecord {
  const TripRecord({
    required this.id, required this.receipt,
    this.pickup = '', this.dropoff = '',
    this.vehicleType = '', this.vehiclePlate = '',
    this.vehicleBrand = '',
    this.fareProfileName = '', this.tariffSnapshot,
    this.paymentMethod = PaymentMethod.cash,
    this.routePoints = const [],
  });
  final String id;
  final TripReceipt receipt;
  final String pickup, dropoff;
  final String vehicleType, vehiclePlate, vehicleBrand, fareProfileName;
  final TariffConfig? tariffSnapshot;
  final PaymentMethod paymentMethod;
  final List<TripRoutePoint> routePoints;

  TripRecord copyWith({PaymentMethod? paymentMethod}) => TripRecord(
    id: id, receipt: receipt, pickup: pickup, dropoff: dropoff,
    vehicleType: vehicleType, vehiclePlate: vehiclePlate,
    vehicleBrand: vehicleBrand,
    fareProfileName: fareProfileName, tariffSnapshot: tariffSnapshot,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    routePoints: routePoints,
  );

  factory TripRecord.fromReceipt(TripReceipt receipt,
      {String pickup = '', String dropoff = '',
       String vehicleType = '', String vehiclePlate = '',
       String vehicleBrand = '',
       String fareProfileName = '', TariffConfig? tariffSnapshot,
       List<TripRoutePoint> routePoints = const []}) => TripRecord(
    id: receipt.startedAt.microsecondsSinceEpoch.toString() +
        '-' + receipt.endedAt.microsecondsSinceEpoch.toString(),
    receipt: receipt, pickup: pickup, dropoff: dropoff,
    vehicleType: vehicleType, vehiclePlate: vehiclePlate,
    vehicleBrand: vehicleBrand,
    fareProfileName: fareProfileName, tariffSnapshot: tariffSnapshot,
    routePoints: List<TripRoutePoint>.unmodifiable(routePoints),
  );

  Map<String, dynamic> toJson() => {
    'version': 3, 'id': id, 'receipt': receipt.toJson(),
    'pickup': pickup, 'dropoff': dropoff,
    'vehicleType': vehicleType, 'vehiclePlate': vehiclePlate,
    'vehicleBrand': vehicleBrand,
    'fareProfileName': fareProfileName,
    'tariff': tariffSnapshot == null
        ? null : jsonDecode(TariffCodec.encode(tariffSnapshot!)),
    'paymentMethod': paymentMethod.name,
    'routePoints': routePoints.map((p) => p.toJson()).toList(),
  };
  String encode() => jsonEncode(toJson());
  factory TripRecord.decode(String source) =>
      TripRecord.fromJson(Map<String, dynamic>.from(jsonDecode(source) as Map));

  static double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static TripReceipt _readReceipt(Map<String, dynamic> json) {
    final started = DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final ended = DateTime.tryParse(json['endedAt']?.toString() ?? '') ?? started;
    return TripReceipt(
      startedAt: started, endedAt: ended,
      distanceKm: _number(json, 'distanceKm'),
      durationSeconds: _number(json, 'durationSeconds').toInt(),
      waitingSeconds: _number(json, 'waitingSeconds').toInt(),
      baseFare: _number(json, 'baseFare'),
      distanceFare: _number(json, 'distanceFare'),
      waitingFare: _number(json, 'waitingFare'),
      tollFee: _number(json, 'tollFee'),
      surcharge: _number(json, 'surcharge'),
      discount: _number(json, 'discount'),
      totalFare: _number(json, 'totalFare'),
      isFlatFare: json['isFlatFare'] == true,
    );
  }

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    // Earlier MVP stored TripReceipt.toJson directly in preferences.
    final inner = json['receipt'];
    final receipt = _readReceipt(inner is Map
        ? Map<String, dynamic>.from(inner) : json);
    final legacyId = receipt.startedAt.microsecondsSinceEpoch.toString() +
        '-' + receipt.endedAt.microsecondsSinceEpoch.toString();
    return TripRecord(
      id: json['id']?.toString() ?? legacyId,
      receipt: receipt,
      pickup: json['pickup']?.toString() ?? '',
      dropoff: json['dropoff']?.toString() ?? '',
      vehicleType: json['vehicleType']?.toString() ?? '',
      vehiclePlate: json['vehiclePlate']?.toString() ?? '',
      vehicleBrand: json['vehicleBrand']?.toString() ?? '',
      fareProfileName: json['fareProfileName']?.toString() ?? '',
      tariffSnapshot: json['tariff'] is Map
          ? TariffCodec.decode(jsonEncode(json['tariff'])) : null,
      paymentMethod: PaymentMethod.fromCode(
        json['paymentMethod']?.toString()),
      routePoints: json['routePoints'] is List
          ? (json['routePoints'] as List).map((p) =>
              TripRoutePoint.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList(growable: false)
          : const [],
    );
  }
}
