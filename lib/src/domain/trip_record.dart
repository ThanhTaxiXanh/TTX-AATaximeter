import 'dart:convert';
import '../core/taximeter_engine.dart';

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
    this.paymentMethod = PaymentMethod.cash,
  });
  final String id;
  final TripReceipt receipt;
  final String pickup, dropoff;
  final PaymentMethod paymentMethod;

  TripRecord copyWith({PaymentMethod? paymentMethod}) => TripRecord(
    id: id, receipt: receipt, pickup: pickup, dropoff: dropoff,
    paymentMethod: paymentMethod ?? this.paymentMethod,
  );

  factory TripRecord.fromReceipt(TripReceipt receipt,
      {String pickup = '', String dropoff = ''}) => TripRecord(
    id: receipt.startedAt.microsecondsSinceEpoch.toString() +
        '-' + receipt.endedAt.microsecondsSinceEpoch.toString(),
    receipt: receipt, pickup: pickup, dropoff: dropoff,
  );

  Map<String, dynamic> toJson() => {
    'version': 2, 'id': id, 'receipt': receipt.toJson(),
    'pickup': pickup, 'dropoff': dropoff,
    'paymentMethod': paymentMethod.name,
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
      paymentMethod: PaymentMethod.fromCode(
        json['paymentMethod']?.toString()),
    );
  }
}
