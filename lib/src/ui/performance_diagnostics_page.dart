import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'driver_pro_design.dart';
import 'performance_monitor.dart';

/// Snapshot of non-sensitive GPS and map state. No coordinates or receipts.
class DiagnosticsRuntime {
  const DiagnosticsRuntime({
    required this.storageReady,
    required this.gpsStatus,
    required this.foregroundGpsSubscribed,
    required this.lastTrustedFix,
    required this.map3D,
    required this.routeCount,
    required this.mapObservations,
    required this.mapRevisions,
  });

  final bool storageReady;
  final String gpsStatus;
  final bool foregroundGpsSubscribed;
  final DateTime? lastTrustedFix;
  final bool map3D;
  final int routeCount, mapObservations, mapRevisions;

  String trustedFixAge(DateTime now) {
    final last = lastTrustedFix;
    if (last == null) return 'Chưa có vị trí GPS tin cậy';
    final elapsed = now.difference(last);
    if (elapsed.isNegative) return 'Đồng hồ thiết bị thay đổi';
    if (elapsed.inSeconds < 1) return 'Vừa nhận';
    return '${elapsed.inSeconds} giây trước';
  }
}

class PerformanceDiagnosticsPage extends StatefulWidget {
  const PerformanceDiagnosticsPage({
    super.key,
    required this.monitor,
    required this.readRuntime,
  });

  final PerformanceMonitor monitor;
  final DiagnosticsRuntime Function() readRuntime;

  @override
  State<PerformanceDiagnosticsPage> createState() =>
      _PerformanceDiagnosticsPageState();
}

class _PerformanceDiagnosticsPageState
    extends State<PerformanceDiagnosticsPage> {
  @override
  void initState() {
    super.initState();
    // Starting an opt-in monitor notifies the underlying map HUD listener.
    // Defer that notification until the new route has finished building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.monitor.setMonitoring(true);
    });
  }

  @override
  void dispose() {
    // Keep sampling only while the driver's overlay is actively selected.
    if (!widget.monitor.overlayEnabled) widget.monitor.setMonitoring(false);
    super.dispose();
  }

  String _ms(num? ms) => ms == null ? '—' : '${ms.toStringAsFixed(1)} ms';
  String _intMs(int? ms) => ms == null ? '—' : '$ms ms';
  String _rss(int? bytes) =>
      bytes == null ? '—' : '${(bytes / 1000000).toStringAsFixed(1)} MB';

  Widget _metric(String title, String value, IconData icon,
      {Color color = DriverProColors.cyan}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: DriverProColors.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: DriverProColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(height: 10),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22,
            fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(
          color: DriverProColors.muted, fontSize: 11)),
      ],
    ),
  );

  String _report(DiagnosticsRuntime r) {
    final m = widget.monitor;
    final fps = m.flutterFps;
    return [
      'TTX DRIVER PRO • Chẩn đoán hiệu năng (không có tọa độ GPS)',
      'Khung hình đầu: ${_intMs(m.firstFrameMs)}',
      'Khôi phục dữ liệu: ${_intMs(m.storageReadyMs)}',
      'SQLite: ${m.storageOk == true ? 'Sẵn sàng' : 'Chưa xác minh'}',
      'Flutter FPS quan sát: ${fps?.toStringAsFixed(1) ?? '—'}',
      'UI p95: ${_ms(m.uiBuildP95Ms)}',
      'Raster p95: ${_ms(m.rasterP95Ms)}',
      'RAM tiến trình RSS: ${_rss(m.residentBytes)}',
      'Số khung Flutter mẫu: ${m.frameSamples}',
      'GPS: ${r.gpsStatus}',
      'GPS chuyến đang đăng ký: ${r.foregroundGpsSubscribed}',
      'Fix tin cậy gần nhất: ${r.trustedFixAge(DateTime.now())}',
      'Chế độ bản đồ: ${r.map3D ? '3D' : '2D'}',
      'Điểm GPS trong tuyến: ${r.routeCount}',
      'Quan sát GPS hiển thị: ${r.mapObservations}',
      'Lần yêu cầu cập nhật bản đồ: ${r.mapRevisions}',
      'Lưu ý: FPS Flutter không đo renderer native MapLibre.',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.monitor,
    builder: (context, child) {
      final m = widget.monitor;
      final r = widget.readRuntime();
      return Scaffold(
        backgroundColor: DriverProColors.background,
        appBar: AppBar(
          title: const Text('Chẩn đoán hiệu năng',
            style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [IconButton(
            tooltip: 'Sao chép báo cáo không có tọa độ',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _report(r)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép báo cáo hiệu năng')),
                );
              }
            },
          )],
        ),
        body: SafeArea(child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            const DriverProPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THEO DÕI TRÊN THIẾT BỊ',
                  style: TextStyle(color: DriverProColors.cyan,
                    fontWeight: FontWeight.w900, fontSize: 12)),
                SizedBox(height: 8),
                Text('Chỉ đo khi mở trang này hoặc bật HUD đo trên bản đồ. '
                  'Không gửi dữ liệu lên máy chủ, không lưu tọa độ hay hóa đơn.',
                  style: TextStyle(color: DriverProColors.muted, fontSize: 12)),
              ],
            )),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) => GridView.count(
              crossAxisCount: 2,
              childAspectRatio: constraints.maxWidth < 340 ? 1.35 : 1.60,
              mainAxisSpacing: 9, crossAxisSpacing: 9,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              children: [
                _metric('Khung Flutter đầu', _intMs(m.firstFrameMs),
                    Icons.rocket_launch_outlined),
                _metric('Khôi phục dữ liệu', _intMs(m.storageReadyMs),
                    Icons.storage_outlined),
                _metric('Flutter FPS quan sát',
                    m.flutterFps?.toStringAsFixed(1) ?? '—',
                    Icons.speed_outlined, color: DriverProColors.green),
                _metric('RAM tiến trình (RSS)', _rss(m.residentBytes),
                    Icons.memory_rounded),
                _metric('UI p95', _ms(m.uiBuildP95Ms),
                    Icons.dashboard_outlined),
                _metric('Raster p95', _ms(m.rasterP95Ms),
                    Icons.layers_outlined),
              ],
            )),
            const SizedBox(height: 14),
            DriverProPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GPS & BẢN ĐỒ',
                  style: TextStyle(fontWeight: FontWeight.w900,
                    color: DriverProColors.cyan)),
                const SizedBox(height: 10),
                _line('Trạng thái', r.gpsStatus),
                _line('Theo dõi GPS chuyến',
                  r.foregroundGpsSubscribed ? 'Đang đăng ký' : 'Không đăng ký'),
                _line('Fix GPS tin cậy', r.trustedFixAge(DateTime.now())),
                _line('Bản đồ đang chọn', r.map3D ? '3D' : '2D'),
                _line('Điểm tuyến đang lưu', '${r.routeCount}'),
                _line('Quan sát / cập nhật map',
                  '${r.mapObservations} / ${r.mapRevisions}'),
                _line('Số khung Flutter mẫu', '${m.frameSamples}'),
              ],
            )),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              key: const Key('performance-overlay-toggle'),
              activeTrackColor: DriverProColors.blue,
              secondary: const Icon(Icons.picture_in_picture_alt_outlined,
                color: DriverProColors.cyan),
              title: const Text('Hiển thị HUD đo trên bản đồ',
                style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Bật để xem FPS Flutter, UI p95 và RAM '
                'ngay trên màn hình chính. Tắt để ngừng đo khi đóng trang.'),
              value: m.overlayEnabled,
              onChanged: m.setOverlayEnabled,
            ),
            if (m.overlayEnabled)
              FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Quay về bản đồ và xem HUD'),
              ),
            const SizedBox(height: 10),
            const Text(
              'FPS là số khung Flutter quan sát được, không phải FPS của '
              'bản đồ MapLibre native hay tần số màn hình. '
              'Khi giao diện ít thay đổi, FPS Flutter có thể thấp là bình thường. '
              'RAM RSS không bao gồm toàn bộ bộ nhớ GPU. '
              'Đo lặp lại trên cùng thiết bị để so sánh giữa các phiên bản.',
              style: TextStyle(fontSize: 11, height: 1.5,
                color: DriverProColors.muted),
            ),
          ],
        )),
      );
    },
  );

  Widget _line(String name, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 5, child: Text(name,
        style: const TextStyle(color: DriverProColors.muted, fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(flex: 6, child: Text(value,
        textAlign: TextAlign.end, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
    ]),
  );
}

/// Compact on-map view, updated only at monitor's two-second cadence.
class PerformanceMapHud extends StatelessWidget {
  const PerformanceMapHud({super.key, required this.monitor});
  final PerformanceMonitor monitor;

  @override
  Widget build(BuildContext context) => Container(
    width: 166,
    padding: const EdgeInsets.fromLTRB(11, 8, 4, 8),
    decoration: BoxDecoration(
      color: const Color(0xED0A1828),
      border: Border.all(color: DriverProColors.cyan, width: 1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('TTX PERFORMANCE',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
              color: DriverProColors.cyan)),
          const SizedBox(height: 3),
          Text('Flutter ${monitor.flutterFps?.toStringAsFixed(1) ?? '—'} FPS',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          Text('UI p95 ${monitor.uiBuildP95Ms?.toStringAsFixed(1) ?? '—'} ms',
            style: const TextStyle(fontSize: 10)),
          Text('RAM ${monitor.residentBytes == null ? '—' : (monitor.residentBytes! / 1e6).toStringAsFixed(0)} MB',
            style: const TextStyle(fontSize: 10)),
        ],
      )),
      IconButton(
        tooltip: 'Tắt HUD và ngừng đo hiệu năng',
        icon: const Icon(Icons.close_rounded, size: 17),
        color: Colors.white70,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 30),
        onPressed: () => monitor.setMonitoring(false),
      ),
    ]),
  );
}
