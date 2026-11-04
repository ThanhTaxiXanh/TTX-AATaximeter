import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Real, interactive OSM-based map in the phone dashboard.
/// This is NOT a turn-by-turn navigator or a native Android Auto screen.
/// Default camera is a Vietnam overview, never a presumed user location.
class DashboardMap extends StatefulWidget {
  const DashboardMap({
    super.key, required this.latitude, required this.longitude,
    required this.onLocate, required this.speedKmh,
    required this.speedLimitKmh,
  });
  final double? latitude, longitude;
  final VoidCallback onLocate;
  final double speedKmh, speedLimitKmh;
  @override
  State<DashboardMap> createState() => _DashboardMapState();
}

class _DashboardMapState extends State<DashboardMap> {
  final MapController controller = MapController();
  bool mapReady = false;
  bool follow = true;

  bool get hasFix => widget.latitude != null &&
      widget.longitude != null &&
      widget.latitude!.abs() <= 90 && widget.longitude!.abs() <= 180;

  LatLng get position => LatLng(widget.latitude!, widget.longitude!);

  @override
  void didUpdateWidget(covariant DashboardMap old) {
    super.didUpdateWidget(old);
    if (mapReady && follow && hasFix &&
        (old.latitude != widget.latitude || old.longitude != widget.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && mapReady && follow && hasFix) {
          controller.move(position, controller.camera.zoom < 11
              ? 15 : controller.camera.zoom);
        }
      });
    }
  }

  void center() {
    if (!hasFix) {
      widget.onLocate();
      return;
    }
    setState(() => follow = true);
    if (mapReady) controller.move(position, 16);
  }

  void zoom(double offset) {
    if (!mapReady) return;
    final zoom = (controller.camera.zoom + offset).clamp(3.0, 19.0);
    controller.move(controller.camera.center, zoom);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(17),
    child: SizedBox(height: 335, child: Stack(children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: hasFix
              ? position : const LatLng(16.0, 107.5),
          initialZoom: hasFix ? 15 : 5.2,
          minZoom: 3, maxZoom: 19,
          onMapReady: () {
            mapReady = true;
            if (hasFix && follow) controller.move(position, 15);
          },
          onPositionChanged: (camera, gesture) {
            if (gesture && follow && mounted) {
              setState(() => follow = false);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'vn.thanhtaxixanh.ttx_aataximeter',
            maxNativeZoom: 19,
          ),
          if (hasFix)
            MarkerLayer(markers: [
              Marker(
                point: position, width: 44, height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xCC071824),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00D8F0),
                      width: 2)),
                  child: const Icon(Icons.navigation,
                    color: Color(0xFF00D8F0), size: 26),
                ),
              ),
            ]),
        ],
      ),
      Positioned(top: 8, left: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE5080C18),
            borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.map_outlined, size: 17,
                color: Color(0xFF00D8F0)),
              const SizedBox(width: 5),
              Text(hasFix ? 'BẢN ĐỒ / VỊ TRÍ GPS' : 'BẢN ĐỒ / CHỜ VỊ TRÍ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11)),
            ]),
          )),
      ),
      Positioned(right: 8, top: 8,
        child: Column(children: [
          _control(Icons.my_location, center, 'Về vị trí xe'),
          const SizedBox(height: 6),
          _control(Icons.add, () => zoom(1), 'Phóng to'),
          const SizedBox(height: 6),
          _control(Icons.remove, () => zoom(-1), 'Thu nhỏ'),
          const SizedBox(height: 6),
          _control(Icons.explore_outlined,
            () { if (mapReady) controller.rotate(0); },
            'Trở về hướng Bắc'),
        ]),
      ),
      Positioned(bottom: 8, left: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEB10131D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF303543)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
                Text(widget.speedKmh.round().toString() + ' km/h',
                  style: const TextStyle(
                    color: Color(0xFFFF4549), fontSize: 20,
                    fontWeight: FontWeight.w900)),
                Text('Giới hạn cài đặt: ' +
                    widget.speedLimitKmh.round().toString() + ' km/h',
                  style: const TextStyle(
                    color: Colors.white70, fontSize: 9)),
              ]),
          ),
        ),
      ),
      Positioned(bottom: 5, right: 7,
        child: Container(
          color: const Color(0xDEFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: const Text('© OpenStreetMap contributors',
            style: TextStyle(fontSize: 10, color: Colors.black)),
        )),
    ])),
  );

  Widget _control(IconData icon, VoidCallback tap, String title) =>
      Material(
        color: const Color(0xEC111829),
        borderRadius: BorderRadius.circular(9),
        child: IconButton(
          icon: Icon(icon, color: const Color(0xFF00D8F0)),
          iconSize: 21, visualDensity: VisualDensity.compact,
          tooltip: title, onPressed: tap),
      );
}
