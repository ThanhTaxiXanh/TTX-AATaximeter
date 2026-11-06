import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import '../domain/trip_route_point.dart';
import 'drive_map_3d.dart';
import 'follow_camera_gate.dart';
import 'raster_tile_failover.dart';
import 'driver_pro_design.dart';

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
    required this.showCurrentRoadName,
    this.routePoints = const [],
    this.height = 335,
  });
  final double? latitude, longitude;
  final double speedKmh, speedLimitKmh, headingDegrees, pitchDegrees;
  final bool is3D, dark, showCurrentRoadName;
  final double height;
  final VoidCallback onLocate, onToggle3D, onToggleDark;
  final List<TripRoutePoint> routePoints;

  @override
  State<DashboardMap> createState() => _DashboardMapState();
}

class _DashboardMapState extends State<DashboardMap> {
  final fm.MapController _map = fm.MapController();
  final GlobalKey<DriveMap3DState> _driveKey = GlobalKey<DriveMap3DState>();
  // Distinct native map states: switching fallback 2D <-> real 3D must
  // recreate their style layers (including optional building extrusions).
  final GlobalKey<DriveMap3DState> _flatVectorKey =
      GlobalKey<DriveMap3DState>();

  DriveMap3DState? get _activeVectorMap => widget.is3D
      ? _driveKey.currentState : _flatVectorKey.currentState;
  bool _ready = false, _follow = true;
  final FollowCameraGate _twoDFollowGate =
      FollowCameraGate(minimumDistanceMeters: 3.0);
  final RasterTileFailover _tileFailover = RasterTileFailover();
  bool _vector2DFallback = false;
  String? _currentRoadName;
  int _rasterTileEpoch = 0;
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
    if (old.is3D != widget.is3D ||
        old.showCurrentRoadName != widget.showCurrentRoadName) {
      _currentRoadName = null;
      _ready = false;
      _follow = true;
      _twoDFollowGate.reset();
    }
    if (!widget.is3D && _ready && _follow && _hasFix &&
        (old.latitude != widget.latitude ||
         old.longitude != widget.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready && _follow &&
            !widget.is3D && _hasFix) {
          final zoom = _map.camera.zoom < 11 ? 15.0 : _map.camera.zoom;
          if (_twoDFollowGate.shouldUpdate(
            at: DateTime.now(), latitude: widget.latitude!,
            longitude: widget.longitude!, bearing: 0, zoom: zoom,
          )) {
            _map.move(_position, zoom);
          }
        }
      });
    }
  }

  void _center() {
    if (!_hasFix) {
      widget.onLocate();
      return;
    }
    if (widget.is3D || _vector2DFallback) {
      _activeVectorMap?.centerOnCar();
      return;
    }
    setState(() => _follow = true);
    _twoDFollowGate.reset();
    if (_ready) _map.move(_position, 16);
  }

  void _zoom(double amount) {
    if (widget.is3D || _vector2DFallback) {
      _activeVectorMap?.zoomBy(amount);
      return;
    }
    if (!_ready) return;
    _map.move(_map.camera.center,
      (_map.camera.zoom + amount).clamp(3.0, 19.0).toDouble());
  }

  /// A run of failed OSM raster requests is a signal to switch sources, not
  /// a signal to abandon GPS. MapLibre uses the already-configured legal
  /// OpenFreeMap vector service, only as an on-demand fallback.
  void _handleRasterTileError(Object error, int requestEpoch) {
    // A prior TileLayer may complete after a manual retry or mode switch.
    if (requestEpoch != _rasterTileEpoch ||
        widget.is3D || _vector2DFallback) return;
    debugPrint('TTX 2D raster tile failed: $error');
    if (!_tileFailover.recordFailure()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.is3D || !_tileFailover.useVectorFallback) return;
      setState(() {
        _ready = false;
        _vector2DFallback = true;
      });
    });
  }

  void _select2DBaseMap() {
    if (widget.is3D) return;
    setState(() {
      // Invalidate late raster callbacks before changing the source.
      _rasterTileEpoch++;
      _tileFailover.reset();
      _vector2DFallback = !_vector2DFallback;
      _ready = false;
      _follow = true;
      _twoDFollowGate.reset();
    });
  }

  Widget _rasterTileLayer() {
    final epoch = _rasterTileEpoch;
    final tiles = fm.TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'vn.thanhtaxixanh.ttx_aataximeter',
      maxNativeZoom: 19,
      errorTileCallback: (tile, error, stackTrace) =>
          _handleRasterTileError(error, epoch),
    );
    // Never apply a transparent BlendMode.dst color filter in light mode.
    // Some Android render paths leave the texture entirely blank.
    if (!widget.dark) return tiles;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.64, 0, 0, 0, 181,
        0, -0.64, 0, 0, 182,
        0, 0, -0.64, 0, 197,
        0, 0, 0, 1, 0,
      ]),
      child: tiles,
    );
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
      _rasterTileLayer(),
      if (routeLines.isNotEmpty) fm.PolylineLayer(polylines: routeLines),
      if (_hasFix) fm.MarkerLayer(markers: [
        fm.Marker(
          point: _position, width: 46, height: 46,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xCC071824),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00D8F0), width: 2)),
            child: Transform.rotate(
              angle: (widget.headingDegrees.isFinite
                  ? widget.headingDegrees : 0) * math.pi / 180,
              child: const Icon(Icons.navigation_rounded,
                color: DriverProColors.cyan, size: 27)),

          ),
        ),
      ]),
    ],
    );
  }

  Widget _button(Widget child, VoidCallback tap, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: const Color(0xF20A1B2F),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: DriverProColors.border, width: 1),
        borderRadius: BorderRadius.circular(12)),
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

  Widget _mapModeOption(String label, bool selected) => InkWell(
    onTap: selected ? null : widget.onToggle3D,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 40, height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? DriverProColors.blue
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9)),
      child: Text(label, style: TextStyle(
        fontWeight: FontWeight.w900,
        color: selected ? Colors.white : DriverProColors.muted,
        fontSize: 13)),
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
        width: 60, height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE52B35), width: 6),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 5),
          ],
        ),
        child: Text(limit == 0 ? '—' : limit.toString(),
          style: const TextStyle(color: Colors.black,
            fontSize: 24, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 6),
      Container(
        width: 65, height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xED06101E),
          border: Border.all(
            color: overspeed ? DriverProColors.red
                : DriverProColors.cyan, width: 3),
          boxShadow: const [BoxShadow(
            color: Color(0x66000000), blurRadius: 8)],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(current.toString(), style: TextStyle(
              color: overspeed ? DriverProColors.red : Colors.white,
              fontSize: 26, height: 1.0,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()])),
            const Text('km/h', style: TextStyle(
              color: DriverProColors.muted, fontSize: 10)),
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
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: widget.height,
      child: Stack(children: [
        Positioned.fill(child: (widget.is3D || _vector2DFallback)
          ? DriveMap3D(
              key: widget.is3D ? _driveKey : _flatVectorKey,
              flat2D: !widget.is3D,
              latitude: widget.latitude,
              longitude: widget.longitude,
              headingDegrees: widget.headingDegrees,
              speedKmh: widget.speedKmh,
              pitchDegrees: widget.pitchDegrees,
              dark: widget.dark,
              routePoints: widget.routePoints,
              onRoadNameChanged: widget.showCurrentRoadName
                ? (value) {
                    if (!mounted || value == _currentRoadName) return;
                    setState(() => _currentRoadName = value);
                  }
                : null,
            )
          : _twoD(),
        ),
        Positioned(top: 8, left: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xEE06101F),
              border: Border.all(color: DriverProColors.border),
              borderRadius: BorderRadius.circular(9)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_hasFix ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                  size: 13, color: _hasFix
                      ? DriverProColors.green : DriverProColors.amber),
                const SizedBox(width: 4),
                Text(_hasFix ? (widget.is3D ? 'GPS • 3D'
                    : (_vector2DFallback ? 'GPS • VECTOR'
                    : 'VỊ TRÍ GPS')) : 'CHỜ GPS',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w800)),
              ]),
            ),
          )),
        Positioned(top: 7, right: 7,
          child: Material(
            color: const Color(0xF1081425),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _mapModeOption('2D', !widget.is3D),
                _mapModeOption('3D', widget.is3D),
              ]),
            ),
          ),
        ),
        Positioned(right: 7, top: 48,
          child: Column(children: [
            if (!widget.is3D)
              _button(Icon(_vector2DFallback
                  ? Icons.refresh_rounded : Icons.layers_outlined,
                  color: DriverProColors.cyan, size: 22),
                _select2DBaseMap,
                _vector2DFallback ? 'Thử lại nền OSM'
                    : 'Đổi nền 2D sang OpenFreeMap'),
            _button(Icon(widget.dark
                  ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: DriverProColors.amber, size: 22),
              widget.onToggleDark,
              widget.dark ? 'Chuyển bản đồ sáng'
                  : 'Chuyển bản đồ tối'),
            _button(const Icon(Icons.my_location_rounded,
                color: DriverProColors.cyan, size: 21),
              _center, 'Về vị trí xe'),
            _button(const Icon(Icons.add_rounded,
                color: DriverProColors.cyan, size: 22),
              () => _zoom(1), 'Phóng to'),
            _button(const Icon(Icons.remove_rounded,
                color: DriverProColors.cyan, size: 22),
              () => _zoom(-1), 'Thu nhỏ'),
          ]),
        ),
        if (widget.showCurrentRoadName)
          Positioned(right: 8, bottom: 27,
            child: IgnorePointer(child: ConstrainedBox(
              // A short road like "QL1A" only uses its text width; longer
              // names grow until the safe map-area width is reached.
              constraints: BoxConstraints(maxWidth:
                  (MediaQuery.sizeOf(context).width * 0.66)
                      .clamp(145.0, 375.0)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xF0091929),
                  border: Border.all(color: DriverProColors.green, width: 1.4),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(
                    color: Color(0x65000000), blurRadius: 10)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.signpost_outlined,
                    color: DriverProColors.green, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_currentRoadName ??
                      (_hasFix ? 'Đang xác định tên đường...'
                          : 'Đang chờ vị trí GPS'),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _currentRoadName == null
                        ? DriverProColors.muted : Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 12.5))),
                ]),
              ),
            )),
          ),
        Positioned(left: 8, bottom: 8, child: _speedPanel()),
        if (!widget.is3D && !_vector2DFallback)
          const Positioned(right: 5, bottom: 3,
            child: Text('© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Colors.black87,
                backgroundColor: Color(0xCCFFFFFF)))),
      ]),
    ),
  );
}
