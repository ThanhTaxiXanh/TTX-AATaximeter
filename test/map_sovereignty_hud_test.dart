import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/map_sovereignty_hud.dart';
import 'package:ttx_aataximeter/src/ui/vietnam_map_sovereignty.dart';

void main() {
  testWidgets('fixed HUD renders both mandatory labels exactly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 300, child: MapSovereigntyHud()),
        ),
      ),
    ));

    expect(find.text(VietnamMapSovereignty.hoangSa), findsOneWidget);
    expect(find.text(VietnamMapSovereignty.truongSa), findsOneWidget);
    expect(find.byKey(const Key('ttx-hud-hoang-sa')), findsOneWidget);
    expect(find.byKey(const Key('ttx-hud-truong-sa')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact HUD keeps both labels with larger text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
            ),
            child: const SizedBox(
              width: 190,
              child: MapSovereigntyHud(),
            ),
          ),
        ),
      ),
    ));

    expect(find.text(VietnamMapSovereignty.hoangSa), findsOneWidget);
    expect(find.text(VietnamMapSovereignty.truongSa), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
