import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/toll_schedule.dart';

void main() {
  test('no preset toll until user configures a stop', () {
    const s = TollSchedule();
    expect(TollSchedule.decode(s.encode()).rates, isEmpty);
  });
  test('named toll price survives local storage', () {
    const rates = TollSchedule(rates: [
      TollRate(id: 'a', label: 'Trạm BOT A', amount: 35000),
      TollRate(id: 'b', label: 'Trạm BOT B', amount: 22000),
    ]);
    final restored = TollSchedule.decode(rates.encode());
    expect(restored.rates.length, 2);
    expect(restored.rates.last.label, 'Trạm BOT B');
    expect(restored.rates.fold<double>(
        0, (sum, e) => sum + e.amount), 57000);
  });
  test('reject invalid or duplicate toll fees', () {
    expect(() => const TollSchedule(rates: [
      TollRate(id: 'a', label: 'Trạm', amount: -1),
    ]).encode(), throwsFormatException);
    expect(() => const TollSchedule(rates: [
      TollRate(id: 'x', label: 'A', amount: 10000),
      TollRate(id: 'x', label: 'B', amount: 20000),
    ]).encode(), throwsFormatException);
  });
}
