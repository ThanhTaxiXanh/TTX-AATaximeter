import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/trip_record.dart';
import '../domain/trip_route_point.dart';
import 'driver_pro_design.dart';
import 'vietnam_map_sovereignty.dart';

String formatTripDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return two(local.hour) + ':' + two(local.minute) + ' ngày ' +
      local.day.toString() + ' thg ' + local.month.toString() +
      ', ' + local.year.toString();
}

String _money(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.') + ' đ';

/// Read-only journey map. Historical receipts without GPS samples do not
/// invent a route or claim a map snapshot exists.
class TripRouteMap extends StatefulWidget {
  const TripRouteMap({super.key, required this.points});
  final List<TripRoutePoint> points;

  @override
  State<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<TripRouteMap> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final samples = widget.points;
    if (samples.isEmpty) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DriverProColors.panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 42, color: Colors.white54),
            SizedBox(height: 10),
            Text('Chuyến này chưa có dữ liệu tuyến GPS',
              style: TextStyle(color: Colors.white70)),
            Text('Tuyến đường được ghi từ các chuyến mới',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
      );
    }
    final coordinates = samples.map(
      (p) => LatLng(p.latitude, p.longitude)).toList();
    final grouped = <int, List<LatLng>>{};
    for (final point in samples) {
      grouped.putIfAbsent(point.segment, () => []).add(
        LatLng(point.latitude, point.longitude));
    }
    final lines = grouped.values.where((v) => v.length > 1)
        .map((points) => Polyline(
          points: points,
          color: const Color(0xFF08B4FA),
          strokeWidth: 5,
        )).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 285,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: coordinates.first,
            initialZoom: 14,
            onMapReady: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (coordinates.length > 1) {
                  _controller.fitCamera(CameraFit.coordinates(
                    coordinates: coordinates,
                    padding: const EdgeInsets.all(55),
                    maxZoom: 16,
                  ));
                }
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: VietnamMapSovereignty.osmRasterTiles,
              userAgentPackageName: 'vn.thanhtaxixanh.ttx_aataximeter',
            ),
            if (lines.isNotEmpty) PolylineLayer(polylines: lines),
            MarkerLayer(markers: [
              // App-owned Vietnam-facing island/sea names are displayed
              // wherever their approximate label anchors enter the viewport.
              for (final label in VietnamMapSovereignty.labels)
                Marker(
                  point: LatLng(label.latitude, label.longitude),
                  width: 166, height: 34,
                  child: IgnorePointer(child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xE6091F33),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: DriverProColors.cyan)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 5),
                        child: Text(label.name,
                          style: const TextStyle(
                            fontSize: 11, color: Colors.white,
                            fontWeight: FontWeight.w800)),
                      ),
                    ),
                  )),
                ),
              Marker(
                point: coordinates.first, width: 44, height: 44,
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF24C956),
                  child: Icon(Icons.play_arrow, color: Colors.white),
                ),
              ),
              if (coordinates.length > 1)
                Marker(
                  point: coordinates.last, width: 44, height: 44,
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFFFF4549),
                    child: Icon(Icons.stop, color: Colors.white),
                  ),
                ),
            ]),
            const Positioned(
              left: 10, bottom: 7,
              child: Text('© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black,
                  backgroundColor: Color(0xDDEEEEEE))),
            ),
          ],
        ),
      ),
    );
  }
}

class TripDetailPage extends StatelessWidget {
  const TripDetailPage({
    super.key,
    required this.record,
    required this.onReceipt,
  });

  final TripRecord record;
  final Future<void> Function() onReceipt;

  Widget _information(IconData icon, String title, String value,
      {Color color = Colors.white}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: DriverProColors.panel,
      border: Border.all(color: DriverProColors.border),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(children: [
      Icon(icon, color: DriverProColors.cyan, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Text(title,
        style: const TextStyle(color: Colors.white60, fontSize: 15))),
      Flexible(child: Text(value,
        textAlign: TextAlign.end,
        style: TextStyle(color: color, fontWeight: FontWeight.w700,
          fontSize: 15))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final receipt = record.receipt;
    final profile = record.fareProfileName.isNotEmpty
        ? record.fareProfileName
        : (record.vehicleType.isNotEmpty ? record.vehicleType : 'Xe taxi');
    return Scaffold(
      backgroundColor: DriverProColors.background,
      appBar: AppBar(
        backgroundColor: DriverProColors.backgroundDeep,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Chi tiết chuyến đi'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Xong', style: TextStyle(fontSize: 17))),
        ],
      ),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 30),
        children: [
          TripRouteMap(points: record.routePoints),
          const SizedBox(height: 17),
          _information(Icons.local_taxi, 'Loại xe / Bảng giá', profile),
          if (record.vehicleBrand.isNotEmpty)
            _information(Icons.directions_car_outlined,
              'Hãng xe', record.vehicleBrand),
          if (record.vehiclePlate.isNotEmpty)
            _information(Icons.confirmation_number_outlined,
              'Biển số xe', record.vehiclePlate),
          _information(Icons.access_time, 'Giờ bắt đầu',
            formatTripDate(receipt.startedAt)),
          _information(Icons.access_time_filled, 'Giờ kết thúc',
            formatTripDate(receipt.endedAt)),
          _information(Icons.timer_outlined, 'Thời gian',
            (receipt.durationSeconds ~/ 60).toString() + ' phút'),
          _information(Icons.map_outlined, 'Quãng đường',
            receipt.distanceKm.toStringAsFixed(2) + ' km'),
          _information(Icons.payments_outlined, 'Thành tiền',
            _money(receipt.totalFare), color: DriverProColors.green),
          const SizedBox(height: 12),
          const Text('Thông tin thêm',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 10),
          _information(Icons.toll_outlined, 'Trạm thu phí',
            _money(receipt.tollFee)),
          if (receipt.waitingFare > 0)
            _information(Icons.hourglass_bottom, 'Phí chờ',
              _money(receipt.waitingFare)),
          _information(Icons.account_balance_wallet_outlined,
            'Thanh toán', record.paymentMethod.label),
          const SizedBox(height: 8),
          DriverProAction(
            label: 'Xem hóa đơn và thanh toán',
            icon: Icons.receipt_long_outlined,
            color: DriverProColors.blue,
            onPressed: onReceipt,
          ),
          if (record.routePoints.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Đường xanh là các tọa độ GPS đã được chấp nhận. '
                'Đoạn mất tín hiệu không được nối hoặc tự tính cước. '
                'Nền bản đồ cần Internet để tải.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
        ],
      )),
    );
  }
}
