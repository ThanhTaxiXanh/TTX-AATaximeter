import 'dart:convert';
import '../core/taximeter_engine.dart';
import 'tariff_codec.dart';

/// Versioned, standalone crash-recovery record. It includes the original
/// tariff and route so changing settings does not recalculate a live trip.
class TripSessionSnapshot {
  const TripSessionSnapshot({
    required this.meter,
    required this.tariff,
    required this.pickup,
    required this.dropoff,
  });

  final Map<String, dynamic> meter;
  final TariffConfig tariff;
  final String pickup;
  final String dropoff;

  factory TripSessionSnapshot.fromEngine(
    TaximeterEngine engine, {
    String pickup = '',
    String dropoff = '',
  }) => TripSessionSnapshot(
    meter: engine.exportSnapshot(),
    tariff: engine.tariff,
    pickup: pickup,
    dropoff: dropoff,
  );

  String encode() => jsonEncode({
    'schema': 1,
    'meter': meter,
    'tariff': jsonDecode(TariffCodec.encode(tariff)),
    'pickup': pickup,
    'dropoff': dropoff,
  });

  factory TripSessionSnapshot.decode(String json) {
    final root = jsonDecode(json);
    if (root is! Map || root['schema'] != 1 ||
        root['meter'] is! Map || root['tariff'] is! Map) {
      throw const FormatException('Invalid trip session payload');
    }
    final savedTariff = TariffCodec.decode(jsonEncode(root['tariff']));
    return TripSessionSnapshot(
      meter: Map<String, dynamic>.from(root['meter'] as Map),
      tariff: savedTariff,
      pickup: root['pickup']?.toString() ?? '',
      dropoff: root['dropoff']?.toString() ?? '',
    );
  }

  TaximeterEngine restore({DateTime? at}) => TaximeterEngine.fromSnapshot(
    tariff: tariff,
    snapshot: meter,
    recoveredAt: at,
  );
}
