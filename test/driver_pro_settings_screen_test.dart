import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/domain/dashboard_preferences.dart';
import 'package:ttx_aataximeter/src/ui/driver_pro_settings_screen.dart';

void main() {
  testWidgets('settings search finds VietQR and passes selected action',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(home: DriverProSettingsScreen(
      initial: const DashboardPreferences(),
      onAction: (value) => selected = value,
      onPreferencesChanged: (_) {},
    )));
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Trung tâm điều khiển'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'VietQR');
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản ngân hàng VietQR'), findsOneWidget);
    await tester.tap(find.text('Tài khoản ngân hàng VietQR'));
    await tester.pump();
    expect(selected, 'bank');
  });

  testWidgets('map toggles save preferences without changing meter',
      (tester) async {
    DashboardPreferences? updated;
    await tester.pumpWidget(MaterialApp(home: DriverProSettingsScreen(
      initial: const DashboardPreferences(showCurrentRoadName: true),
      onAction: (_) {},
      onPreferencesChanged: (value) => updated = value,
    )));
    await tester.ensureVisible(find.text('Hiển thị tên đường đang đi'));
    await tester.pumpAndSettle();
    final tile = find.ancestor(
      of: find.text('Hiển thị tên đường đang đi'),
      matching: find.byType(SwitchListTile));
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(updated?.showCurrentRoadName, false);
  });
}
