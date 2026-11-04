import 'trip_record.dart';

enum RevenuePeriod { today, week, month, all }

/// The report is calculated solely from completed, locally stored receipts.
/// A truly empty 0đ/0km/0-second test record stays in SQLite but is hidden
/// from the default business view; a genuine free/short ride is retained.
class RevenueSummary {
  const RevenueSummary({
    required this.trips,
    required this.totalFare,
    required this.totalDistanceKm,
  });

  final List<TripRecord> trips;
  final double totalFare, totalDistanceKm;

  int get tripCount => trips.length;
  double get averageFare => tripCount == 0 ? 0 : totalFare / tripCount;

  static RevenueSummary calculate(
    List<TripRecord> records, {
    required RevenuePeriod period,
    required DateTime now,
  }) {
    final current = now.toLocal();
    DateTime? start;
    switch (period) {
      case RevenuePeriod.today:
        start = DateTime(current.year, current.month, current.day);
      case RevenuePeriod.week:
        final today = DateTime(current.year, current.month, current.day);
        start = today.subtract(Duration(days: today.weekday - 1));
      case RevenuePeriod.month:
        start = DateTime(current.year, current.month);
      case RevenuePeriod.all:
        start = null;
    }

    final matches = records.where((trip) {
      final r = trip.receipt;
      if (r.totalFare <= 0 && r.distanceKm <= 0 &&
          r.durationSeconds <= 0) return false;
      final date = r.startedAt.toLocal();
      return !date.isAfter(current) &&
          (start == null || !date.isBefore(start));
    }).toList()
      ..sort((a, b) => b.receipt.startedAt.compareTo(a.receipt.startedAt));

    return RevenueSummary(
      trips: List<TripRecord>.unmodifiable(matches),
      totalFare: matches.fold<double>(
        0, (sum, r) => sum + r.receipt.totalFare),
      totalDistanceKm: matches.fold<double>(
        0, (sum, r) => sum + r.receipt.distanceKm),
    );
  }
}
