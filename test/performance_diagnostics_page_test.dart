import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_aataximeter/src/ui/performance_monitor.dart';
import 'package:ttx_aataximeter/src/ui/performance_diagnostics_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GPS age displays no coordinates and handles unavailable fixes', () {
    const r = DiagnosticsRuntime(
      storageReady: true,
      gpsStatus: 'GPS nền ±5 m',
      foregroundGpsSubscribed: true,
      lastTrustedFix: null,
      map3D: true,
      routeCount: 250,
      mapObservations: 500,
      mapRevisions: 150,
    );
    expect(r.trustedFixAge(DateTime.utc(2026)), contains('Chưa có'));
  });

  testWidgets('diagnostics are opt-in and the map HUD toggle is controllable',
      (tester) async {
    final monitor = PerformanceMonitor(isVisible: () => true);
    monitor.markStorageFinished(const Duration(milliseconds: 500),
      successful: true);
    await tester.pumpWidget(MaterialApp(
      home: PerformanceDiagnosticsPage(
        monitor: monitor,
        readRuntime: () => const DiagnosticsRuntime(
          storageReady: true,
          gpsStatus: 'GPS sẵn sàng',
          foregroundGpsSubscribed: false,
          lastTrustedFix: null,
          map3D: false,
          routeCount: 0,
          mapObservations: 0,
          mapRevisions: 0,
        ),
      ),
    ));
    expect(find.text('Chẩn đoán hiệu năng'), findsOneWidget);
    expect(find.text('500 ms'), findsOneWidget);
    expect(monitor.monitoring, isTrue);
    final toggle = find.byKey(const Key('performance-overlay-toggle'));
    await tester.scrollUntilVisible(toggle, 260.0,
      scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.text('Hiển thị HUD đo trên bản đồ'), findsOneWidget);
    // Change the setting directly to also cover the notifier rebuild.
    monitor.setOverlayEnabled(true);
    await tester.pump();
    expect(monitor.overlayEnabled, isTrue);
    expect(find.text('Quay về bản đồ và xem HUD'), findsOneWidget);
    monitor.setMonitoring(false);
    await tester.pump();
    expect(monitor.overlayEnabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    monitor.dispose();
  });
}
