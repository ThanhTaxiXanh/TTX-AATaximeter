import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/core/taximeter_engine.dart';
import 'package:ttx_aataximeter/src/ui/driver_pro_design.dart';

void main() {
  Widget shell(Widget body) => MaterialApp(
    home: Scaffold(body: Center(child: body)),
  );

  testWidgets('Driver Pro renders the four fare lifecycle statuses',
      (tester) async {
    await tester.pumpWidget(shell(const DriverProStatusBanner(
      status: MeterStatus.idle)));
    expect(find.text('SẴN SÀNG'), findsOneWidget);

    await tester.pumpWidget(shell(const DriverProStatusBanner(
      status: MeterStatus.running)));
    expect(find.text('ĐANG CHẠY'), findsOneWidget);

    await tester.pumpWidget(shell(const DriverProStatusBanner(
      status: MeterStatus.paused)));
    expect(find.text('TẠM DỪNG'), findsOneWidget);

    await tester.pumpWidget(shell(const DriverProStatusBanner(
      status: MeterStatus.finished)));
    expect(find.text('HOÀN THÀNH'), findsOneWidget);
  });

  testWidgets('manual GPS recovery is explicit, never visually running',
      (tester) async {
    await tester.pumpWidget(shell(const DriverProStatusBanner(
      status: MeterStatus.paused,
      requiresManualResume: true)));
    expect(find.text('CHỜ TIẾP TỤC'), findsOneWidget);
    expect(find.text('ĐANG CHẠY'), findsNothing);
  });

  testWidgets('live fare is accessible and remains easy to read',
      (tester) async {
    await tester.pumpWidget(shell(const SizedBox(
      width: 340,
      child: DriverProFareCard(
        amount: '125.000 đ', status: MeterStatus.running))));
    expect(find.byKey(const Key('driver-pro-fare-card')),
      findsOneWidget);
    expect(find.byKey(const Key('live-fare-total')),
      findsOneWidget);
    expect(find.text('Tiền cước tạm tính'), findsOneWidget);
    expect(find.text('125.000 đ'), findsOneWidget);
  });

  testWidgets('ready screen quote card opens quotation on tap',
      (tester) async {
    var openCount = 0;
    await tester.pumpWidget(shell(SizedBox(
      width: 340,
      child: DriverProQuoteCard(onPressed: () => openCount++),
    )));
    expect(find.byKey(const Key('driver-pro-quote-card')),
      findsOneWidget);
    expect(find.text('Báo giá chuyến đi'), findsOneWidget);
    expect(find.text('Ước tính cước / giá trọn gói'), findsOneWidget);
    await tester.tap(find.text('Báo giá chuyến đi'));
    expect(openCount, 1);
    expect(find.byKey(const Key('driver-pro-fare-card')), findsNothing);
  });

  testWidgets('quote card is disabled while trip data is still loading',
      (tester) async {
    await tester.pumpWidget(shell(const SizedBox(
      width: 340,
      child: DriverProQuoteCard(onPressed: null),
    )));
    expect(find.byKey(const Key('driver-pro-quote-card')),
      findsOneWidget);
    expect(find.text('Báo giá chuyến đi'), findsOneWidget);
    await tester.tap(find.text('Báo giá chuyến đi'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Driver Pro action is a real tappable button',
      (tester) async {
    var count = 0;
    await tester.pumpWidget(shell(SizedBox(
      width: 280,
      child: DriverProAction(
        label: 'Bắt đầu',
        icon: Icons.play_arrow_rounded,
        color: DriverProColors.green,
        darkText: true,
        onPressed: () => count++,
      ),
    )));
    await tester.tap(find.text('Bắt đầu'));
    expect(count, 1);
  });
}
