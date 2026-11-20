import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttx_aataximeter/src/ui/dashboard_map.dart';
import 'package:ttx_aataximeter/src/ui/map_base_source_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reference-only 2D map has no external TileLayer and keeps HUD',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 380,
            child: DashboardMap(
              latitude: null,
              longitude: null,
              speedKmh: 0,
              speedLimitKmh: 0,
              headingDegrees: 0,
              pitchDegrees: 55,
              dark: true,
              is3D: false,
              showCurrentRoadName: false,
              onLocate: () {},
              onToggle3D: () {},
              onToggleDark: () {},
              initial2DBaseSource: Map2DBaseSource.offlineSigns,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // No TileLayer means zero app-initiated HTTP raster tile requests.
    expect(find.byType(fm.TileLayer), findsNothing);
    // Both geographic anchors AND persistent HUD labels can be built.
    // Assert the fixed HUD itself rather than assuming exactly one Text.
    expect(find.byKey(const Key('ttx-hud-hoang-sa')), findsOneWidget);
    expect(find.byKey(const Key('ttx-hud-truong-sa')), findsOneWidget);
    expect(find.text('Hoàng Sa (Việt Nam)'), findsWidgets);
    expect(find.text('Trường Sa (Việt Nam)'), findsWidgets);
    expect(find.textContaining('KHÔNG CÓ BẢN ĐỒ NỀN'), findsOneWidget);
    expect(find.text('CHỜ GPS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
