import 'dart:math' as math;
import '../core/taximeter_engine.dart';

/// Exact distance and charge inside one configured cumulative kilometre band.
class FareBreakdownLine {
  const FareBreakdownLine({
    required this.label,
    required this.fromKm,
    required this.toKm,
    required this.traveledKm,
    required this.ratePerKm,
    required this.amount,
    this.isOpening = false,
  });
  final String label;
  final double fromKm;
  final double? toKm;
  final double traveledKm;
  final double? ratePerKm;
  final double amount;
  final bool isOpening;
  double? get capacityKm => toKm == null ? null : toKm! - fromKm;
}

/// The opening fee covers 0..baseDistanceKm exactly once. Every subsequent
/// tier applies only to its OWN slice of measured distance.
List<FareBreakdownLine> calculateFareBreakdown({
  required TariffConfig tariff,
  required double distanceKm,
  required bool tripStarted,
}) {
  tariff.validate();
  if (!distanceKm.isFinite || distanceKm < 0) {
    throw ArgumentError('Quãng đường không hợp lệ');
  }
  final rows = <FareBreakdownLine>[
    FareBreakdownLine(
      label: 'Giá mở cửa',
      fromKm: 0,
      toKm: tariff.baseDistanceKm,
      traveledKm: math.min(distanceKm, tariff.baseDistanceKm),
      ratePerKm: null,
      amount: tripStarted ? tariff.baseFare : 0,
      isOpening: true,
    ),
  ];
  var from = tariff.baseDistanceKm;
  for (var i = 0; i < tariff.effectiveFareTiers.length; i++) {
    final band = tariff.effectiveFareTiers[i];
    final upper = band.upToKm;
    final kmInBand = math.max(
      0.0, math.min(distanceKm, upper ?? distanceKm) - from,
    );
    rows.add(FareBreakdownLine(
      label: 'Bậc ' + (i + 1).toString(),
      fromKm: from,
      toKm: upper,
      traveledKm: kmInBand,
      ratePerKm: band.ratePerKm,
      amount: tripStarted ? kmInBand * band.ratePerKm : 0,
    ));
    if (upper != null) from = upper;
  }
  return List.unmodifiable(rows);
}
