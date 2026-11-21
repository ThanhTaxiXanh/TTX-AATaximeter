import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/traffic_signs/domain/traffic_sign.dart';
import 'package:ttx_aataximeter/src/traffic_signs/presentation/traffic_sign_details.dart';

void main() {
  testWidgets('unverified raw sign details do not suggest legal validity',
      (tester) async {
    const sign = TrafficSign(
      signId: 0, longitude: 105.86576, latitude: 21.00896,
      signTypeCode: 43, directionRaw: 255, valueRaw: 0,
      speedKmhInferred: null,
      sourceDataset: 'synthetic_test_only',
      verificationStatus: 'unverified',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TrafficSignDetails(sign: sign)),
    ));
    expect(find.textContaining('ID: 0'), findsOneWidget);
    expect(find.textContaining('Mã loại biển: 43'), findsOneWidget);
    expect(find.textContaining('Hướng thô: 255'), findsOneWidget);
    expect(find.textContaining('Chưa xác định (mã 43)'),
      findsOneWidget);
    expect(find.textContaining('Chưa có dữ liệu'), findsOneWidget);
    expect(find.textContaining('Không dùng làm giới hạn tốc độ'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });  testWidgets('confirmed owner code and raw posted speed are shown', 
      (tester) async {
    const sign = TrafficSign(
      signId: 17, longitude: 106.12, latitude: 21.28,
      signTypeCode: 1, directionRaw: 255, valueRaw: 80,
      speedKmhInferred: 80,
      sourceDataset: 'synthetic_test_only',
      verificationStatus: 'unverified',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TrafficSignDetails(sign: sign)),
    ));
    expect(find.text('Loại biển: Biển báo tốc độ'), findsOneWidget);
    expect(find.textContaining('Số trên biển tốc độ: 80 km/h'),
      findsOneWidget);
    expect(find.textContaining('Chưa xác minh hiệu lực thực địa'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('raw number on a camera does not become a speed sign', 
      (tester) async {
    const sign = TrafficSign(
      signId: 18, longitude: 106.12, latitude: 21.28,
      signTypeCode: 4, directionRaw: 255, valueRaw: 178,
      speedKmhInferred: null,
      sourceDataset: 'synthetic_test_only',
      verificationStatus: 'unverified',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TrafficSignDetails(sign: sign)),
    ));
    expect(find.text('Loại biển: Camera giao thông'), findsOneWidget);
    expect(find.text('Giá trị thô: 178'), findsOneWidget);
    expect(find.textContaining('Số trên biển tốc độ'), findsNothing);
  });
  testWidgets('detail card renders the exact user-supplied pictogram', 
      (tester) async {
    const sign = TrafficSign(
      signId: 2, longitude: 106.0, latitude: 21.0,
      signTypeCode: 2, directionRaw: 255, valueRaw: 0,
      speedKmhInferred: null,
      sourceDataset: 'synthetic_test_only',
      verificationStatus: 'unverified',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TrafficSignDetails(sign: sign)),
    ));
    expect(find.text('Loại biển: Vào khu dân cư'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


}
