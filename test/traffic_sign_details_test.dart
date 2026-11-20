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
    expect(find.textContaining('Loại biển chưa được xác minh'),
      findsOneWidget);
    expect(find.textContaining('Chưa có dữ liệu'), findsOneWidget);
    expect(find.textContaining('Không dùng làm giới hạn tốc độ'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
