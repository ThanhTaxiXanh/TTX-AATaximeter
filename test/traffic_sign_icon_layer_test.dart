import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';
import 'package:ttx_aataximeter/src/traffic_signs/presentation/traffic_sign_layer.dart';

void main() {
  testWidgets('FlutterMap 2D displays owner PNG and preserves tap by sign ID',
      (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 400,
        child: fm.FlutterMap(
          options: const fm.MapOptions(
            initialCenter: ll.LatLng(21.0, 106.0), initialZoom: 16,
          ),
          children: [
            TrafficSignLayer(
              items: const [
                SignMapItem(signId: 2, longitude: 106.0, latitude: 21.0,
                  count: 1, signTypeCode: 2, valueRaw: 0),
              ],
              onSelect: selected.add,
              onCluster: (_) {},
            ),
          ],
        ),
      )),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sign-2')));
    expect(selected, [2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no guessed image for speed and ambiguous parking codes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 400,
        child: fm.FlutterMap(
          options: const fm.MapOptions(
            initialCenter: ll.LatLng(21.0, 106.0), initialZoom: 16,
          ),
          children: [
            TrafficSignLayer(
              items: const [
                SignMapItem(signId: 1, longitude: 106.0, latitude: 21.0,
                  count: 1, signTypeCode: 1, valueRaw: 80),
                SignMapItem(signId: 50, longitude: 106.0001, latitude: 21.0,
                  count: 1, signTypeCode: 50, valueRaw: 0),
              ],
              onSelect: (_) {},
              onCluster: (_) {},
            ),
          ],
        ),
      )),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
