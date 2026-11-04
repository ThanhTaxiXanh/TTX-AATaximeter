import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../core/taximeter_engine.dart';
import '../domain/fare_breakdown.dart';

String _vnd(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.',
) + ' đ';

/// Cumulative tier details are calculated from the tariff stored with the
/// trip, never from the current globally selected tariff of another trip.
class FareBreakdownSection extends StatelessWidget {
  const FareBreakdownSection({
    super.key,
    required this.tariff,
    required this.distanceKm,
    required this.tripStarted,
    required this.totalFare,
    this.isFlatFare = false,
    this.waitingFare = 0,
    this.tollFee = 0,
    this.surcharge = 0,
    this.discount = 0,
  });
  final TariffConfig tariff;
  final double distanceKm;
  final bool tripStarted;
  final double totalFare;
  final bool isFlatFare;
  final double waitingFare, tollFee, surcharge, discount;

  Widget _extra(String title, double amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(
        color: Colors.white70, fontSize: 13))),
      Text(_vnd(amount), style: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.w600)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final items = calculateFareBreakdown(
      tariff: tariff, distanceKm: distanceKm, tripStarted: tripStarted,
    );
    final displayed = isFlatFare ? const <FareBreakdownLine>[] : items;
    final openingAndDistance = displayed.fold<double>(
      0, (total, line) => total + line.amount);
    final raw = isFlatFare ? totalFare
        : openingAndDistance + waitingFare + tollFee + surcharge - discount;
    final rounding = totalFare - raw;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (isFlatFare)
        Card(color: const Color(0xFF202125), child: Padding(
          padding: const EdgeInsets.all(13),
          child: _extra('Cước trọn gói', totalFare),
        )),
      for (final line in displayed)
        Card(
          margin: const EdgeInsets.only(bottom: 7),
          color: const Color(0xFF202125),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(line.label,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700))),
                Text(line.isOpening
                    ? '0–' + line.toKm!.toStringAsFixed(2) + ' km'
                    : line.fromKm.toStringAsFixed(2) + '–' +
                      (line.toKm?.toStringAsFixed(2) ?? '∞') + ' km',
                  style: const TextStyle(
                    fontSize: 12, color: Colors.white60)),
              ]),
              const SizedBox(height: 6),
              Text(line.isOpening
                  ? 'Đã đi: ' + line.traveledKm.toStringAsFixed(2) +
                    ' / ' + (line.capacityKm ?? 0).toStringAsFixed(2) + ' km'
                  : 'Đã tính: ' + line.traveledKm.toStringAsFixed(2) +
                    (line.capacityKm == null
                        ? ' km • Không giới hạn'
                        : ' / ' + line.capacityKm!.toStringAsFixed(2) + ' km') +
                    ' × ' + _vnd(line.ratePerKm ?? 0) + '/km',
                style: const TextStyle(
                  fontSize: 12, color: Colors.white60)),
              const SizedBox(height: 7),
              Text(_vnd(line.amount),
                style: const TextStyle(
                  fontSize: 23,
                  color: Color(0xFFFF4549),
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
            ]),
          ),
        ),
      if (tripStarted && (waitingFare != 0 || tollFee != 0 ||
          surcharge != 0 || discount != 0 || rounding.abs() >= .01))
        Card(color: const Color(0xFF202125),
          child: Padding(padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (waitingFare != 0) _extra('Phí chờ', waitingFare),
              if (tollFee != 0) _extra('Phí BOT / cầu đường', tollFee),
              if (surcharge != 0) _extra('Phụ thu', surcharge),
              if (discount != 0) _extra('Giảm giá', -discount),
              if (rounding.abs() >= .01)
                _extra('Điều chỉnh làm tròn', rounding),
            ]),
          )),
      Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        child: Row(children: [
          const Expanded(child: Text('TỔNG CƯỚC',
            style: TextStyle(fontWeight: FontWeight.bold))),
          Text(_vnd(totalFare),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF4549), fontSize: 21)),
        ]),
      ),
    ]);
  }
}
