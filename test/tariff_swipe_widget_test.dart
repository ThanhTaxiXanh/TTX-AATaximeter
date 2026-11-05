import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/tariff_catalog.dart';
import 'package:ttx_aataximeter/src/ui/tariff_catalog_page.dart';

void main() {
  testWidgets('swiping left reveals Edit and Delete, confirmation removes row',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TariffCatalogPage(initial: TariffCatalog.initial()),
    ));
    expect(find.text('Taxi Hương Giang'), findsOneWidget);
    await tester.drag(find.text('Taxi Hương Giang'), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sửa'), findsOneWidget);
    expect(find.text('Xóa'), findsOneWidget);
    await tester.tap(find.text('Xóa').first);
    await tester.pumpAndSettle();
    expect(find.text('Xóa bảng giá?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Taxi Hương Giang'), findsNothing);
    expect(find.text('Taxi Đô Thị 4 Chỗ (mẫu tham khảo)'), findsOneWidget);
  });
}
