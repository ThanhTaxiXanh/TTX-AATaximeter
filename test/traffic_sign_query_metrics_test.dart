import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/data/traffic_sign_query_metrics.dart';

void main() {
  test('bounded SQL samples calculate p50 and p95 nearest-rank', () {
    final stats = TrafficSignQueryMetrics(capacity: 3);
    stats.record(const Duration(milliseconds: 1), succeeded: true);
    stats.record(const Duration(milliseconds: 3), succeeded: true);
    stats.record(const Duration(milliseconds: 5), succeeded: true);
    expect(stats.p50Ms, 3);
    expect(stats.p95Ms, 5);
    expect(stats.queryCount, 3);
    expect(stats.sampleCount, 3);

    stats.record(const Duration(milliseconds: 9), succeeded: true);
    expect(stats.sampleCount, 3); // Discards oldest 1 ms sample.
    expect(stats.queryCount, 4);
    expect(stats.p50Ms, 5);
    expect(stats.p95Ms, 9);
  });

  test('failed queries are counted but do not corrupt latency percentiles', () {
    final stats = TrafficSignQueryMetrics(capacity: 2);
    stats.record(const Duration(milliseconds: 1), succeeded: false);
    expect(stats.failureCount, 1);
    expect(stats.queryCount, 1);
    expect(stats.p50Ms, isNull);
    expect(stats.summary, contains('chưa có mẫu thành công'));

    stats.record(const Duration(microseconds: 500), succeeded: true);
    expect(stats.p50Ms, closeTo(0.5, 0.001));
    expect(stats.p95Ms, closeTo(0.5, 0.001));
    expect(stats.summary, contains('0.5 ms'));
    expect(stats.summary, contains('lỗi 1'));
    // The summary has no raw GPS coordinates or private trip metadata.
    expect(stats.summary, isNot(contains('latitude')));
    expect(stats.summary, isNot(contains('longitude')));
  });

  test('negative or huge wall-time values never enter the rolling ring', () {
    final stats = TrafficSignQueryMetrics(capacity: 1);
    stats.record(const Duration(microseconds: -100), succeeded: true);
    expect(stats.p50Ms, 0);
    stats.record(const Duration(days: 999), succeeded: true);
    expect(stats.sampleCount, 1);
    expect(stats.p95Ms, lessThanOrEqualTo(2147483.647));
  });
}
