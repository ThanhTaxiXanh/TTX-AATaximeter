import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/ui/fare_breakdown_section.dart';

void main() {
  testWidgets('shows opening and exact 28.5km segment', (tester) async {
    final tariff = TariffConfig.demo().copyWith(
      baseFare: 30000, baseDistanceKm: 1.5,
      fareTiers: const [
        FareTier(upToKm: 30, ratePerKm: 15000),
        FareTier(upToKm: null, ratePerKm: 12000),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: SingleChildScrollView(child:
        FareBreakdownSection(
          tariff: tariff, distanceKm: 10,
          tripStarted: true, totalFare: 157500,
        ),
      )),
    ));
    expect(find.text('Giá mở cửa'), findsOneWidget);
    expect(find.text('0–1.50 km'), findsOneWidget);
    expect(find.text('30.000 đ'), findsWidgets);
    expect(find.text('1.50–30.00 km'), findsOneWidget);
    expect(find.textContaining('8.50 / 28.50 km'), findsOneWidget);
    expect(find.text('127.500 đ'), findsOneWidget);
    expect(find.text('TỔNG CƯỚC'), findsOneWidget);
  });
}
