import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import '../domain/trip_route_point.dart';
import 'drive_map_3d.dart';

/// Lightweight OSM 2D map by default; native MapLibre only mounts in 3D.
class DashboardMap extends StatefulWidget {
  const DashboardMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.speedLimitKmh,
    required this.onLocate,
    required this.is3D,
    required this.dark,
    required this.pitchDegrees,
    required this.headingDegrees,
    required this.onToggle3D,
    required this.onToggleDark,
    this.routePoints = const [],
  });
  final double? latitude, longitude;
  final double speedKmh, speedLimitKmh, headingDegrees, pitchDegrees;
  final bool is3D, dark;
  final VoidCallback onLocate, onToggle3D, onToggleDark;
  final List<TripRoutePoint> routePoints;

  @override
  State<DashboardMap> createState() => _DashboardMapState();
}

class _DashboardMapState extends State<DashboardMap> {
  final fm.MapController _map = fm.MapController();
  final GlobalKey<DriveMap3DState> _driveKey = GlobalKey<DriveMap3DState>();
  bool _ready = false, _follow = true;
  // Route points are append-only within a trip. Rebuild polyline geometries
  // only when the number/tail changes, not on every 1-second fare tick.
  int _cachedRouteCount = -1;
  TripRoutePoint? _cachedRouteTail;
  List<fm.Polyline> _cachedRouteLines = const [];

  bool get _hasFix {
    final lat = widget.latitude, lon = widget.longitude;
    return lat != null && lon != null &&
        lat.isFinite && lon.isFinite &&
        lat.abs() <= 90 && lon.abs() <= 180;
  }

  ll.LatLng get _position => ll.LatLng(widget.latitude!, widget.longitude!);

  @override
  void didUpdateWidget(covariant DashboardMap old) {
    super.didUpdateWidget(old);
    if (old.is3D != widget.is3D) {
      _ready = false;
      _follow = true;
    }
    if (!widget.is3D && _ready && _follow && _hasFix &&
        (old.latitude != widget.latitude ||
         old.longitude != widget.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready && _follow &&
            !widget.is3D && _hasFix) {
          _map.move(_position, _map.camera.zoom < 11 ? 15 : _map.camera.zoom);
        }
      });
    }
  }

  void _center() {
    if (!_hasFix) {
      widget.onLocate();
      return;
    }
    if (widget.is3D) {
      _driveKey.currentState?.centerOnCar();
      return;
    }
    setState(() => _follow = true);
    if (_ready) _map.move(_position, 16);
  }

  void _zoom(double amount) {
    if (widget.is3D) {
      _driveKey.currentState?.zoomBy(amount);
      return;
    }
    if (!_ready) return;
    _map.move(_map.camera.center,
      (_map.camera.zoom + amount).clamp(3.0, 19.0).toDouble());
  }

  void _northUp() {
    if (widget.is3D) {
      _driveKey.currentState?.northUp();
    } else if (_ready) {
      _map.rotate(0);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  List<fm.Polyline> get _routeLines {
    final count = widget.routePoints.length;
    final tail = count == 0 ? null : widget.routePoints.last;
    if (count == _cachedRouteCount &&
        identical(tail, _cachedRouteTail)) return _cachedRouteLines;
    final bySegment = <int, List<ll.LatLng>>{};
    for (final p in widget.routePoints) {
      bySegment.putIfAbsent(p.segment, () => []).add(
        ll.LatLng(p.latitude, p.longitude));
    }
    _cachedRouteLines = bySegment.values.where((points) => points.length > 1)
        .map((points) => fm.Polyline(
          points: points, strokeWidth: 5,
          color: const Color(0xFF08B8F4))).toList(growable: false);
    _cachedRouteCount = count;
    _cachedRouteTail = tail;
    return _cachedRouteLines;
  }

  Widget _twoD() {
    final routeLines = _routeLines;
    return fm.FlutterMap(
    mapController: _map,
    options: fm.MapOptions(
      initialCenter: _hasFix
          ? _position : const ll.LatLng(16.0, 107.5),
      initialZoom: _hasFix ? 15 : 5.2,
      minZoom: 3, maxZoom: 19,
      onMapReady: () {
        _ready = true;
        if (_hasFix && _follow) _map.move(_position, 15);
      },
      onPositionChanged: (camera, gesture) {
        if (gesture && _follow && mounted) {
          setState(() => _follow = false);
        }
      },
    ),
    children: [
      ColorFiltered(
        colorFilter: widget.dark
            ? const ColorFilter.matrix([
                -0.64, 0, 0, 0, 181,
                0, -0.64, 0, 0, 182,
                0, 0, -0.64, 0, 197,
                0, 0, 0, 1, 0,
              ])
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'vn.thanhtaxixanh.ttx_aataximeter',
          maxNativeZoom: 19,
        ),
      ),
      if (routeLines.isNotEmpty) fm.PolylineLayer(polylines: routeLines),
      if (_hasFix) fm.MarkerLayer(markers: [
        fm.Marker(
          point: _position, width: 46, height: 46,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xCC071824),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00D8F0), width: 2)),
            child: const Icon(Icons.navigation,
              color: Color(0xFF00D8F0), size: 26),
          ),
        ),
      ]),
    ],
    );
  }

  Widget _button(Widget child, VoidCallback tap, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Material(
      color: const Color(0xE91A2230),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: hint,
          child: SizedBox(width: 42, height: 40,
            child: Center(child: child)),
        ),
      ),
    ),
  );

  Widget _speedPanel() {
    final current = widget.speedKmh.isFinite
        ? widget.speedKmh.clamp(0, 300).round() : 0;
    final limit = widget.speedLimitKmh.isFinite &&
            widget.speedLimitKmh > 0
        ? widget.speedLimitKmh.round() : 0;
    final overspeed = limit > 0 && current > limit;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 65, height: 65,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE52B35), width: 7),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 5),
          ],
        ),
        child: Text(limit == 0 ? '—' : limit.toString(),
          style: const TextStyle(color: Colors.black,
            fontSize: 25, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 6),
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.dark
              ? const Color(0xDF303741) : const Color(0xEAF5F5F5),
          border: Border.all(
            color: overspeed ? Colors.redAccent : const Color(0xFF999DA4),
            width: 3),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.speed, color: Color(0xFFFAA435), size: 17),
            Text(current.toString(), style: TextStyle(
              color: overspeed ? Colors.redAccent
                : (widget.dark ? Colors.white : Colors.black),
              fontSize: 24, fontWeight: FontWeight.w900)),
            Text('km/h', style: TextStyle(
              color: widget.dark ? Colors.white70 : Colors.black54,
              fontSize: 10)),
          ],
        ),
      ),
      if (overspeed)
        const Text('QUÁ TỐC ĐỘ', style: TextStyle(
          color: Colors.redAccent, fontSize: 9,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xDF101010))),
      const Text('Giới hạn cài đặt', style: TextStyle(
        fontSize: 9, color: Colors.white,
        backgroundColor: Color(0xCC121826))),
    ]);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(17),
    child: SizedBox(
      height: 335,
      child: Stack(children: [
        Positioned.fill(child: widget.is3D
          ? DriveMap3D(
              key: _driveKey,
              latitude: widget.latitude,
              longitude: widget.longitude,
              headingDegrees: widget.headingDegrees,
              pitchDegrees: widget.pitchDegrees,
              dark: widget.dark,
              routePoints: widget.routePoints,
            )
          : _twoD(),
        ),
        Positioned(top: 8, left: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xD908101A),
              borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Text(widget.is3D ? '3D • GÓC NHÌN SAU XE'
                  : (_hasFix ? '2D • VỊ TRÍ GPS' : '2D • CHỜ GPS'),
                style: const TextStyle(
                  color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.bold)),
            ),
          )),
        Positioned(right: 7, top: 7,
          child: Column(children: [
            _button(Text(widget.is3D ? '2D' : '3D',
              style: const TextStyle(color: Colors.cyanAccent,
                fontWeight: FontWeight.w900)), widget.onToggle3D,
              widget.is3D ? 'Chuyển sang 2D' : 'Chuyển sang 3D'),
            _button(Icon(widget.dark ? Icons.dark_mode : Icons.light_mode,
                color: Colors.amberAccent, size: 23),
              widget.onToggleDark,
              widget.dark ? 'Chuyển bản đồ sáng' : 'Chuyển bản đồ tối'),
            _button(const Icon(Icons.explore_outlined,
                color: Colors.cyanAccent, size: 22),
              _northUp, 'Đưa bản đồ về hướng Bắc'),
            _button(const Icon(Icons.my_location,
                color: Colors.cyanAccent, size: 23),
              _center, 'Về vị trí xe'),
            _button(const Icon(Icons.add, color: Colors.cyanAccent),
              () => _zoom(1), 'Phóng to'),
            _button(const Icon(Icons.remove, color: Colors.cyanAccent),
              () => _zoom(-1), 'Thu nhỏ'),
          ]),
        ),
        Positioned(left: 8, bottom: 8, child: _speedPanel()),
        if (!widget.is3D)
          const Positioned(right: 5, bottom: 3,
            child: Text('© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Colors.black87,
                backgroundColor: Color(0xCCFFFFFF)))),
      ]),
    ),
  );
}
