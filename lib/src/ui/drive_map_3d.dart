import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;
import '../domain/trip_route_point.dart';

/// Native MapLibre vector map with pitch, heading-up camera and OSM buildings.
/// It is mounted only while 3D is requested, keeping the initial 2D path fast.
class DriveMap3D extends StatefulWidget {
  const DriveMap3D({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.pitchDegrees,
    required this.dark,
    required this.routePoints,
  });
  final double? latitude, longitude;
  final double headingDegrees, pitchDegrees;
  final bool dark;
  final List<TripRoutePoint> routePoints;

  @override
  State<DriveMap3D> createState() => DriveMap3DState();
}

class DriveMap3DState extends State<DriveMap3D> {
  gl.MapLibreMapController? _map;
  bool _styleReady = false;
  bool _routeReady = false;
  int _lastRouteCount = -1;
  double _zoom = 17;
  bool _followCar = true;

  bool get _hasFix {
    final lat = widget.latitude, lon = widget.longitude;
    return lat != null && lon != null &&
        lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;
  }

  double get _heading => widget.headingDegrees.isFinite
      ? widget.headingDegrees % 360 : 0;

  gl.LatLng get _target {
    if (!_hasFix) return const gl.LatLng(16.0, 107.5);
    final lat = widget.latitude!, lon = widget.longitude!;
    // Shift the map target approximately 35m in front of the car so
    // the car remains in the lower part of the navigation perspective.
    final az = _heading * math.pi / 180;
    const forwardMeters = 35.0;
    final north = forwardMeters * math.cos(az);
    final east = forwardMeters * math.sin(az);
    final longitudeDenominator = math.max(
      0.1, math.cos(lat * math.pi / 180));
    return gl.LatLng(
      (lat + north / 111320).clamp(-85.0, 85.0).toDouble(),
      lon + east / (111320 * longitudeDenominator),
    );
  }

  gl.CameraPosition _camera() => gl.CameraPosition(
    target: _target,
    zoom: _hasFix ? _zoom : 5.3,
    tilt: widget.pitchDegrees.clamp(50.0, 60.0).toDouble(),
    bearing: _hasFix ? _heading : 0,
  );

  @override
  void didUpdateWidget(covariant DriveMap3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) {
      _styleReady = false;
      _routeReady = false;
      _lastRouteCount = -1;
      // MapLibreMap changes styleString and recreates style layers.
    }
    if (oldWidget.pitchDegrees != widget.pitchDegrees ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.headingDegrees != widget.headingDegrees) {
      if (_followCar) _moveToCar();
    }
    if (_lastRouteCount != widget.routePoints.length) {
      unawaited(_refreshRoute());
    }
  }

  void centerOnCar() {
    _followCar = true;
    _moveToCar();
  }

  void zoomBy(double delta) {
    _zoom = (_zoom + delta).clamp(3.0, 19.0).toDouble();
    _moveToCar();
  }

  void northUp() {
    _followCar = false;
    final controller = _map;
    if (controller == null || !_styleReady) return;
    unawaited(controller.animateCamera(
      gl.CameraUpdate.newCameraPosition(gl.CameraPosition(
        target: _target, zoom: _zoom,
        tilt: widget.pitchDegrees.clamp(50.0, 60.0).toDouble(),
        bearing: 0,
      )),
      duration: const Duration(milliseconds: 400),
    ).catchError((Object error) {
      debugPrint('MapLibre north-up failed: $error');
      return false;
    }));
  }

  void _moveToCar() {
    final controller = _map;
    if (controller == null || !_styleReady || !_hasFix || !_followCar) return;
    unawaited(controller.animateCamera(
      gl.CameraUpdate.newCameraPosition(_camera()),
      duration: const Duration(milliseconds: 500),
    ).catchError((Object error) {
      debugPrint('MapLibre camera update failed: $error');
      return false;
    }));
  }

  Map<String, dynamic> _routeGeoJson() {
    final bySegment = <int, List<List<double>>>{};
    for (final point in widget.routePoints) {
      bySegment.putIfAbsent(point.segment, () => []).add(
        [point.longitude, point.latitude]);
    }
    final valid = bySegment.values.where((points) => points.length >= 2)
        .toList(growable: false);
    return {
      'type': 'FeatureCollection',
      'features': valid.isEmpty ? <Object>[] : [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'MultiLineString',
            'coordinates': valid,
          },
        }
      ],
    };
  }

  Future<void> _refreshRoute() async {
    final controller = _map;
    if (!_routeReady || controller == null || !mounted) return;
    final size = widget.routePoints.length;
    if (size == _lastRouteCount) return;
    try {
      await controller.setGeoJsonSource('ttx-route', _routeGeoJson());
      if (mounted) _lastRouteCount = size;
    } catch (error) {
      debugPrint('Cannot update 3D journey line: $error');
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _map;
    if (controller == null || !mounted) return;
    _styleReady = true;
    _routeReady = false;
    _lastRouteCount = -1;
    // Both OpenFreeMap Liberty and Dark use the OpenMapTiles "building"
    // vector source layer. Where OSM has no height, a modest 9m extrusion
    // is an illustration, not a measured real-world building height.
    try {
      await controller.addFillExtrusionLayer(
        'openmaptiles',
        'ttx-3d-buildings',
        gl.FillExtrusionLayerProperties(
          fillExtrusionColor: widget.dark ? '#46546b' : '#b4afa5',
          fillExtrusionOpacity: 0.88,
          fillExtrusionHeight: [
            'coalesce', ['get', 'render_height'], 9
          ],
          fillExtrusionBase: [
            'coalesce', ['get', 'render_min_height'], 0
          ],
        ),
        sourceLayer: 'building',
        minzoom: 14,
      );
    } catch (error) {
      // The map stays usable if this style's building source is missing.
      debugPrint('3D building layer not available: $error');
    }
    try {
      await controller.addGeoJsonSource('ttx-route', _routeGeoJson());
      await controller.addLineLayer(
        'ttx-route',
        'ttx-route-line',
        const gl.LineLayerProperties(
          lineColor: '#00C2FF',
          lineWidth: 5.0,
          lineOpacity: 0.9,
        ),
      );
      _routeReady = true;
      _lastRouteCount = widget.routePoints.length;
    } catch (error) {
      debugPrint('3D route layer not available: $error');
    }
    if (mounted) _moveToCar();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    gl.MapLibreMap(
      styleString: widget.dark
          ? 'https://tiles.openfreemap.org/styles/dark'
          : 'https://tiles.openfreemap.org/styles/liberty',
      initialCameraPosition: _camera(),
      compassEnabled: false,
      attributionEnabled: true,
      logoEnabled: false,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      foregroundLoadColor: widget.dark
          ? const Color(0xFF101A28) : const Color(0xFFEEEAE0),
      onMapCreated: (controller) => _map = controller,
      onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
    ),
    // A custom drawn rear-facing blue car: foreground HUD graphic, NOT a
    // positioned 3D model inside the vector tile renderer.
    if (_hasFix)
      const Align(
        alignment: Alignment(0, 0.67),
        child: IgnorePointer(child: CarPerspectiveMarker()),
      ),
    const Positioned(
      bottom: 6, right: 5,
      child: IgnorePointer(child: Text('© OpenStreetMap • OpenFreeMap',
        style: TextStyle(fontSize: 9,
          color: Colors.black87,
          backgroundColor: Color(0xAAFFFFFF)))),
    ),
  ]);
}

/// Lightweight perspective-drawn car with rear lights and a shaded roof.
class CarPerspectiveMarker extends StatelessWidget {
  const CarPerspectiveMarker({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    height: 94,
    child: CustomPaint(painter: _CarPerspectivePainter()),
  );
}

class _CarPerspectivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(w / 2, h * .85), width: w * .8, height: 18),
      shadowPaint);

    Path shape(List<Offset> vertices) {
      final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
      for (final p in vertices.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }
    // Perspective is foreshortened at the top of the car.
    final shell = shape([
      Offset(w * .32, h * .12),
      Offset(w * .68, h * .12),
      Offset(w * .85, h * .52),
      Offset(w * .81, h * .83),
      Offset(w * .19, h * .83),
      Offset(w * .15, h * .52),
    ]);
    canvas.drawPath(shell, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF79D9FF), Color(0xFF0669D9), Color(0xFF053C85)],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));
    canvas.drawPath(shell, Paint()
      ..color = const Color(0xFFD6F7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7);
    final window = shape([
      Offset(w * .36, h * .23), Offset(w * .64, h * .23),
      Offset(w * .73, h * .52), Offset(w * .27, h * .52),
    ]);
    canvas.drawPath(window, Paint()..color = const Color(0xFF082547));
    canvas.drawPath(window, Paint()
      ..color = const Color(0xFF43B7ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .2, h * .72, w * .6, h * .11),
      const Radius.circular(3)),
      Paint()..color = const Color(0xFF103A66));
    for (final x in [w * .20, w * .71]) {
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, h * .735, w * .09, h * .07),
        const Radius.circular(2)),
        Paint()..color = const Color(0xFFFF2634));
    }
    canvas.drawRect(Rect.fromLTWH(w * .40, h * .78, w * .2, h * .033),
      Paint()..color = const Color(0xFFFFD443));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
