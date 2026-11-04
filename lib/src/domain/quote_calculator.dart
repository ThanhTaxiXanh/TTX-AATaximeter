import 'dart:math' as math;
import '../core/taximeter_engine.dart';

/// Quote calculator validated against the observed 15km one-way video case.
/// Two-way estimate is an independent assumption, NOT reverse-engineered proof.
class QuoteCalculator {
  const QuoteCalculator();

  double estimate({
    required TariffConfig tariff,
    required double distanceKm,
    required double perKmRate,
    double tollFee = 0,
    bool twoWay = false,
    double returnLegDiscount = 0.5,
  }) {
    for (final n in [distanceKm, perKmRate, tollFee, returnLegDiscount]) {
      if (!n.isFinite || n < 0) throw ArgumentError('Giá trị báo giá không hợp lệ');
    }
    if (returnLegDiscount > 1) {
      throw ArgumentError('Giảm chiều về tối đa 100%');
    }
    tariff.validate();
    final outgoing = tariff.baseFare +
        (perKmRate == tariff.perKmRate
            ? tariff.distanceChargeForKm(distanceKm)
            : math.max(0, distanceKm - tariff.baseDistanceKm) * perKmRate);
    // The return-leg discount needs comparison with original two-way behavior.
    final returnFare = twoWay
        ? distanceKm * perKmRate * (1 - returnLegDiscount)
        : 0.0;
    final sum = outgoing + returnFare + tollFee;
    return tariff.roundToThousands
        ? ((sum + 500) / 1000).floorToDouble() * 1000
        : sum;
  }
}
