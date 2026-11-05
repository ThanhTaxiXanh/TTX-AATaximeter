import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/led_marquee_title.dart';

void main() {
  testWidgets('LED greeting moves right to left and stays mounted',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const LedMarqueeTitle()),
      ),
    ));
    const message = 'Chúc quý khách thượng lộ bình an';
    final text = find.byKey(const Key('led-marquee-text'));
    expect(tester.widget<Text>(text).data, message);
    final positioned = find.ancestor(
      of: text, matching: find.byType(Positioned)).first;
    final leftBefore = tester.widget<Positioned>(positioned).left!;
    await tester.pump(const Duration(seconds: 2));
    final leftAfter = tester.widget<Positioned>(positioned).left!;
    expect(leftAfter, lessThan(leftBefore));
    expect(tester.takeException(), isNull);
  });
}
