import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;
import '../domain/trip_route_point.dart';

/// GPS arrow is a native geo-referenced symbol, not a fixed HUD overlay.
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
  bool _arrowReady = false;
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
      _arrowReady = false;
      _lastRouteCount = -1;
      // MapLibreMap changes styleString and recreates style layers.
    }
    if (oldWidget.pitchDegrees != widget.pitchDegrees ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.headingDegrees != widget.headingDegrees) {
      unawaited(_refreshArrow());
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

  Future<void> _refreshArrow() async {
    final controller = _map;
    if (controller == null || !mounted || !_arrowReady) return;
    try {
      await controller.setGeoJsonSource('ttx-gps-arrow-position',
        gpsArrowGeoJson(widget.latitude, widget.longitude, _heading));
    } catch (error) {
      debugPrint('Cannot update GPS arrow: $error');
    }
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
    _arrowReady = false;
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
    // The arrow is anchored at the true WGS84 GPS fix. The camera can be
    // aimed ahead of the car independently without changing the GPS position.
    try {
      await controller.addImage('ttx-3d-navigation-arrow',
        await _paintArrowImage(), false, 2);
      await controller.addGeoJsonSource('ttx-gps-arrow-position',
        gpsArrowGeoJson(widget.latitude, widget.longitude, _heading));
      await controller.addSymbolLayer(
        'ttx-gps-arrow-position', 'ttx-gps-arrow',
        const gl.SymbolLayerProperties(
          iconImage: 'ttx-3d-navigation-arrow',
          iconSize: 0.85,
          iconAnchor: 'center',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          // A world-relative GPS heading stays correct during map rotation.
          iconRotationAlignment: 'map',
          iconPitchAlignment: 'viewport',
          iconRotate: ['get', 'heading'],
        ),
      );
      _arrowReady = true;
      unawaited(_refreshArrow());
    } catch (error) {
      debugPrint('GPS navigation arrow layer unavailable: $error');
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
    const Positioned(
      bottom: 6, right: 5,
      child: IgnorePointer(child: Text('© OpenStreetMap • OpenFreeMap',
        style: TextStyle(fontSize: 9,
          color: Colors.black87,
          backgroundColor: Color(0xAAFFFFFF)))),
    ),
  ]);
}

/// Source coordinates are longitude, latitude in WGS84, not screen pixels.
/// Exposed for unit tests to prevent regressions to a fake 35m GPS offset.
Map<String, dynamic> gpsArrowGeoJson(
    double? latitude, double? longitude, double headingDegrees) {
  final valid = latitude != null && longitude != null &&
      latitude.isFinite && longitude.isFinite &&
      latitude.abs() <= 90 && longitude.abs() <= 180;
  return {
    'type': 'FeatureCollection',
    'features': valid ? [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
        'properties': {
          'heading': headingDegrees.isFinite
              ? ((headingDegrees % 360) + 360) % 360 : 0.0,
        },
      }
    ] : <Object>[],
  };
}

/// Rasterized once per style load; the arrow has shaded faces and a small
/// shadow for perspective but remains a light 2D billboard, not a 3D mesh.
Future<ui.Uint8List> _paintArrowImage() async {
  const size = Size(92, 106);
  const pixelRatio = 2.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  const _GpsArrowPainter().paint(canvas, size);
  final picture = recorder.endRecording();
  final bitmap = await picture.toImage(
      (size.width * pixelRatio).round(), (size.height * pixelRatio).round());
  final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
  bitmap.dispose();
  picture.dispose();
  if (data == null) throw StateError('Cannot render navigation arrow');
  return data.buffer.asUint8List();
}

class _GpsArrowPainter extends CustomPainter {
  const _GpsArrowPainter();

  Path _poly(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const w = 92.0;
    const h = 106.0;
    final outline = _poly(const [
      Offset(46, 8), Offset(82, 85), Offset(49, 67),
      Offset(46, 74), Offset(43, 67), Offset(10, 85),
    ]);
    canvas.drawPath(outline.shift(const Offset(0, 7)),
      Paint()..color = const Color(0x88020A1D)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Left and right bevels make the arrow read as a raised 3D solid.
    canvas.drawPath(outline, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFDCFAFF), Color(0xFF168BEB), Color(0xFF063B92)],
      ).createShader(const Rect.fromLTWH(10, 8, 72, 80)));
    canvas.drawPath(_poly(const [
      Offset(46, 8), Offset(46, 74), Offset(10, 85),
    ]), Paint()..color = const Color(0xFF9AEAFF));
    canvas.drawPath(_poly(const [
      Offset(46, 8), Offset(82, 85), Offset(46, 74),
    ]), Paint()..color = const Color(0xFF0B66CE));
    canvas.drawPath(outline, Paint()
      ..color = const Color(0xFFFBFFFF)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke);
    canvas.drawLine(const Offset(w / 2, 13), const Offset(w / 2, h * .65),
      Paint()..color = const Color(0xAAEFFFFF)..strokeWidth = 1.3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
