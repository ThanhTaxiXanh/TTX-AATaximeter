import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;
import '../domain/trip_route_point.dart';
import 'follow_camera_gate.dart';
import 'navigation_camera_filter.dart';
import 'road_label_style.dart';
import 'nearest_road_name.dart';
import 'route_render_geometry.dart';
import 'road_query_gate.dart';
import 'map_style_epoch.dart';

/// GPS arrow is a native geo-referenced symbol, not a fixed HUD overlay.
/// Native MapLibre vector map with pitch, heading-up camera and OSM buildings.
/// It is mounted only while 3D is requested, keeping the initial 2D path fast.
class DriveMap3D extends StatefulWidget {
  const DriveMap3D({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.speedKmh,
    required this.pitchDegrees,
    required this.dark,
    required this.routePoints,
    this.flat2D = false,
    this.onRoadNameChanged,
  });
  final double? latitude, longitude;
  final double headingDegrees, pitchDegrees, speedKmh;
  final bool dark;
  /// Zero-pitch vector fallback for 2D when raster tiles fail.
  final bool flat2D;
  final List<TripRoutePoint> routePoints;
  final ValueChanged<String?>? onRoadNameChanged;

  @override
  State<DriveMap3D> createState() => DriveMap3DState();
}

class DriveMap3DState extends State<DriveMap3D> {
  gl.MapLibreMapController? _map;
  bool _styleReady = false;
  bool _routeReady = false;
  bool _arrowReady = false;
  bool _updatingArrow = false;
  bool _arrowDirty = false;
  bool _updatingRoute = false;
  bool _routeDirty = false;
  // Avoid uploading the entire accumulated route to native MapLibre for
  // every accepted GPS sample. The saved route itself is never throttled.
  static const Duration _routeRenderInterval = Duration(seconds: 2);
  Timer? _routeRenderTimer;
  DateTime? _lastNativeRouteUpload;
  int _lastRouteCount = -1;
  TripRoutePoint? _lastRoutePoint;
  final RouteRenderGeometryCache _routeGeometry = RouteRenderGeometryCache();
  final FollowCameraGate _cameraGate = FollowCameraGate(
    minimumInterval: const Duration(milliseconds: 620),
    minimumDistanceMeters: 1.8,
    minimumBearingDegrees: 2.5,
  );
  final NavigationCameraFilter _visualCamera = NavigationCameraFilter();
  bool _cameraAnimating = false;
  bool _cameraQueued = false;
  bool _cameraQueuedForce = false;
  double _zoom = 17;
  bool _followCar = true;
  final RoadQueryGate _roadQueryGate = RoadQueryGate();
  final MapStyleEpoch _styleEpoch = MapStyleEpoch();
  bool _roadQueryBusy = false;

  bool _styleActive(gl.MapLibreMapController controller, int epoch) =>
      mounted && _styleReady && identical(_map, controller) &&
      _styleEpoch.isCurrent(epoch);

  bool get _hasFix {
    final lat = widget.latitude, lon = widget.longitude;
    return lat != null && lon != null &&
        lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;
  }

  double get _heading => widget.headingDegrees.isFinite
      ? widget.headingDegrees % 360 : 0;

  gl.LatLng _targetForPose(NavigationCameraPose pose) {
    final lat = pose.latitude, lon = pose.longitude;
    if (widget.flat2D) return gl.LatLng(lat, lon);
    // Only the VISUAL camera looks ahead; the GPS marker and metering
    // continue using the true validated coordinates.
    final az = pose.headingDegrees * math.pi / 180;
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

  gl.CameraPosition _camera({NavigationCameraPose? visualPose}) {
    final pose = visualPose ?? NavigationCameraPose(
      latitude: widget.latitude ?? 16.0,
      longitude: widget.longitude ?? 107.5,
      headingDegrees: _heading);
    return gl.CameraPosition(
      target: _targetForPose(pose),
      zoom: _hasFix ? _zoom : 5.3,
      tilt: widget.flat2D ? 0 :
          widget.pitchDegrees.clamp(50.0, 60.0).toDouble(),
      bearing: widget.flat2D ? 0 : (_hasFix ? pose.headingDegrees : 0),
    );
  }

  @override
  void didUpdateWidget(covariant DriveMap3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) {
      _styleEpoch.invalidate();
      _routeRenderTimer?.cancel();
      _routeRenderTimer = null;
      _lastNativeRouteUpload = null;
      _styleReady = false;
      _routeReady = false;
      _arrowReady = false;
      _lastRouteCount = -1;
      _lastRoutePoint = null;
      _cameraGate.reset();
      _visualCamera.reset();
      _roadQueryGate.reset();
      // MapLibreMap changes styleString and recreates style layers.
    }
    if (oldWidget.flat2D != widget.flat2D) {
      _followCar = true;
      _cameraGate.reset();
      _visualCamera.reset();
    }
    if (oldWidget.flat2D != widget.flat2D ||
        oldWidget.pitchDegrees != widget.pitchDegrees ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.headingDegrees != widget.headingDegrees) {
      if (oldWidget.latitude != widget.latitude ||
          oldWidget.longitude != widget.longitude ||
          oldWidget.headingDegrees != widget.headingDegrees) {
        unawaited(_refreshArrow());
      }
      if (_followCar) _moveToCar();
      if (oldWidget.latitude != widget.latitude ||
          oldWidget.longitude != widget.longitude) {
        unawaited(_updateCurrentRoad());
      }
    }
    if (oldWidget.onRoadNameChanged == null &&
        widget.onRoadNameChanged != null) {
      unawaited(_updateCurrentRoad(force: true));
    }
    if (_lastRouteCount != widget.routePoints.length ||
        !identical(_lastRoutePoint,
            widget.routePoints.isEmpty ? null : widget.routePoints.last)) {
      _scheduleRouteRender();
    }
  }

  void centerOnCar() {
    _followCar = true;
    _visualCamera.reset();
    _cameraGate.reset();
    _moveToCar(force: true);
  }

  void zoomBy(double delta) {
    final controller = _map;
    if (!_followCar && controller != null && _styleReady) {
      // Keep the manually selected map centre when zoom buttons are pressed.
      unawaited(controller.animateCamera(
        gl.CameraUpdate.zoomBy(delta),
        duration: const Duration(milliseconds: 220),
      ).catchError((Object error) {
        debugPrint('MapLibre manual zoom failed: $error');
        return false;
      }));
      return;
    }
    _zoom = (_zoom + delta).clamp(3.0, 19.0).toDouble();
    _moveToCar(force: true);
  }

  void northUp() {
    _followCar = false;
    final controller = _map;
    if (controller == null || !_styleReady) return;
    // Rotate in place; do not jump to the GPS when the user explored the map.
    unawaited(controller.animateCamera(
      gl.CameraUpdate.bearingTo(0),
      duration: const Duration(milliseconds: 300),
    ).catchError((Object error) {
      debugPrint('MapLibre north-up failed: $error');
      return false;
    }));
  }

  /// Serialize native camera animations instead of stacking a new animation
  /// for every GPS callback. The latest position is replayed when one finishes.
  void _moveToCar({bool force = false}) {
    final controller = _map;
    if (controller == null || !_styleReady || !_hasFix || !_followCar) return;
    if (_cameraAnimating) {
      _cameraQueued = true;
      _cameraQueuedForce = _cameraQueuedForce || force;
      return;
    }
    final visual = _visualCamera.update(
      at: DateTime.now(),
      latitude: widget.latitude!,
      longitude: widget.longitude!,
      headingDegrees: _heading,
      speedKmh: widget.speedKmh,
    );
    final next = _camera(visualPose: visual);
    if (!_cameraGate.shouldUpdate(
      at: DateTime.now(), latitude: next.target.latitude,
      longitude: next.target.longitude, bearing: next.bearing,
      zoom: next.zoom, force: force,
    )) return;
    _cameraAnimating = true;
    unawaited(controller.animateCamera(
      gl.CameraUpdate.newCameraPosition(next),
      // Slightly longer native interpolation bridges sparse 1 Hz GPS fixes.
      // These interpolated pixels NEVER feed the billable GPS route.
      duration: const Duration(milliseconds: 700),
    ).catchError((Object error) {
      debugPrint('MapLibre camera update failed: $error');
      return false;
    }).whenComplete(() {
      _cameraAnimating = false;
      final pending = _cameraQueued;
      final forced = _cameraQueuedForce;
      _cameraQueued = false;
      _cameraQueuedForce = false;
      if (pending && mounted && identical(_map, controller) &&
          _styleReady && _followCar) {
        _moveToCar(force: forced);
      }
    }));
  }

  Future<void> _refreshArrow() async {
    final controller = _map;
    if (controller == null || !mounted || !_arrowReady) return;
    if (_updatingArrow) {
      _arrowDirty = true; // Latest GPS wins; do not queue old positions.
      return;
    }
    _updatingArrow = true;
    try {
      do {
        _arrowDirty = false;
        await controller.setGeoJsonSource('ttx-gps-arrow-position',
          gpsArrowGeoJson(widget.latitude, widget.longitude, _heading));
      } while (_arrowDirty && mounted && _arrowReady &&
          identical(_map, controller));
    } catch (error) {
      debugPrint('Cannot update GPS arrow: $error');
    } finally {
      _updatingArrow = false;
    }
  }

  /// Coalesce rapid GPS callbacks into one complete native line update.
  /// This only controls pixels: no recorded route point is removed.
  void _scheduleRouteRender() {
    if (!_routeReady || !mounted) return;
    if (_routeRenderTimer != null) return;
    final last = _lastNativeRouteUpload;
    final age = last == null ? _routeRenderInterval
        : DateTime.now().difference(last);
    if (age >= _routeRenderInterval || age.isNegative) {
      unawaited(_refreshRoute());
      return;
    }
    _routeRenderTimer = Timer(_routeRenderInterval - age, () {
      _routeRenderTimer = null;
      if (mounted) unawaited(_refreshRoute());
    });
  }

  Map<String, dynamic> _routeGeoJson() {
    // Simplification is strictly presentational. Full accepted GPS samples
    // remain in SQLite, receipts and the authoritative fare engine.
    final valid = _routeGeometry.render(widget.routePoints)
        .map((segment) => segment.map((point) =>
            [point.longitude, point.latitude]).toList(growable: false))
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
    if (_updatingRoute) {
      _routeDirty = true;
      return;
    }
    _updatingRoute = true;
    try {
      do {
        _routeDirty = false;
        final count = widget.routePoints.length;
        final last = count == 0 ? null : widget.routePoints.last;
        if (count == _lastRouteCount &&
            identical(last, _lastRoutePoint)) break;
        await controller.setGeoJsonSource('ttx-route', _routeGeoJson());
        if (!mounted || !_routeReady ||
            !identical(_map, controller)) break;
        _lastRouteCount = count;
        _lastRoutePoint = last;
        _lastNativeRouteUpload = DateTime.now();
      } while (_routeDirty && mounted && _routeReady &&
          identical(_map, controller));
    } catch (error) {
      debugPrint('Cannot update 3D journey line: $error');
    } finally {
      _updatingRoute = false;
    }
  }

  /// Improve only visible road line and road-name style layers.
  /// The actual provider Dark style uses grey #505050 road labels and
  /// near-black roads, which become invisible in tilted night navigation.
  Future<void> _enhanceRoadStyle(
      gl.MapLibreMapController controller, int epoch) async {
    try {
      final style = await controller.getStyle();
      if (style == null || style.isEmpty ||
          !_styleActive(controller, epoch)) return;
      if (widget.dark) {
        try {
          await controller.setLayerProperties('background',
            const gl.BackgroundLayerProperties(
              backgroundColor: '#1B2B49'));
        } catch (error) {
          debugPrint('Map background cannot be adjusted: $error');
        }
        // The native Dark style has many almost-black landuse polygons;
        // recoloring background alone leaves a nearly black map.
        for (final entry in darkSurfaceLayerColors(style).entries) {
          if (!_styleActive(controller, epoch)) return;
          try {
            await controller.setLayerProperties(
              entry.key, gl.FillLayerProperties(fillColor: entry.value));
          } catch (error) {
            debugPrint('Dark surface ${entry.key}: $error');
          }
        }
        final colors = darkRoadLayerColors(style);
        for (final entry in colors.entries) {
          if (!_styleActive(controller, epoch)) return;
          try {
            final isInner = entry.key == 'highway_minor' ||
                entry.key == 'highway_major_inner' ||
                entry.key == 'highway_motorway_inner';
            await controller.setLayerProperties(
              entry.key, gl.LineLayerProperties(
                lineColor: entry.value,
                // Reference uses broad slate-blue streets instead of
                // very fine pale wireframe lines at navigation zoom.
                lineWidth: isInner ? [
                  'interpolate', ['linear'], ['zoom'],
                  12, 1.5, 14, 3.2, 16, 7.5, 18, 13.5, 20, 24
                ] : null,
              ));
          } catch (error) {
            debugPrint('Road contrast ${entry.key}: $error');
          }
        }
      }
      for (final id in roadNameSymbolLayerIds(style)) {
        if (!_styleActive(controller, epoch)) return;
        try {
          await controller.setLayerProperties(
            id,
            gl.SymbolLayerProperties(
              textPitchAlignment: 'viewport',
              textRotationAlignment: 'viewport',
              textColor: widget.dark ? '#F2F7FF' : '#233E57',
              textHaloColor: widget.dark ? '#071321' : '#FFFFFF',
              textHaloWidth: widget.dark ? 1.5 : 1.2,
              textSize: widget.dark ? 14.0 : 13.0,
            ),
          );
        } catch (error) {
          debugPrint('Street label style $id: $error');
        }
      }
    } catch (error) {
      // Network tiles and GPS continue even if an external style changes.
      debugPrint('Optional road styling unavailable: $error');
    }
  }

  /// Add an explicit on-road name layer ABOVE 3D buildings.
  /// Native Dark's highway_name_other is only 10px and frequently hidden
  /// by symbol collisions. The new layer draws named OSM road segments
  /// in the road geometry itself, in Vietnamese when present.
  Future<void> _installReadableRoadLabels(
      gl.MapLibreMapController controller, int epoch) async {
    try {
      await controller.addSymbolLayer(
        'openmaptiles',
        'ttx-3d-readable-road-names',
        gl.SymbolLayerProperties(
          symbolPlacement: 'line',
          symbolSpacing: 145,
          textField: [
            'coalesce',
            ['get', 'name:vi'],
            ['get', 'name'],
            ['get', 'name:nonlatin'],
            ['get', 'name:latin'],
            ['get', 'ref'],
            ''
          ],
          textFont: ['Noto Sans Regular'],
          textSize: [
            'interpolate', ['linear'], ['zoom'],
            12, 12, 15, 15, 18, 19
          ],
          textColor: widget.dark ? '#F6F8FE' : '#35465C',
          textHaloColor: widget.dark ? '#182A4C' : '#FFFFFF',
          textHaloWidth: 1.8,
          textHaloBlur: 0.2,
          textPitchAlignment: 'viewport',
          // The text stays vertically upright in perspective while
          // tracking the road line, matching the provided example.
          textRotationAlignment: 'map',
          textKeepUpright: true,
          textMaxAngle: 45,
          textAllowOverlap: false,
          textIgnorePlacement: false,
        ),
        sourceLayer: 'transportation_name',
        minzoom: 12,
        filter: ['any',
          ['has', 'name'], ['has', 'name:vi'],
          ['has', 'name:nonlatin'], ['has', 'name:latin'],
          ['has', 'ref']],
      );
      // Avoid two labels for the same segment. Only hide native labels
      // if the replacement was created successfully.
      if (_styleActive(controller, epoch)) {
        final style = await controller.getStyle();
        if (!_styleActive(controller, epoch)) return;
        if (style != null && style.isNotEmpty) {
          for (final id in roadNameSymbolLayerIds(style)) {
            if (!_styleActive(controller, epoch)) return;
            try {
              await controller.setLayerVisibility(id, false);
            } catch (error) {
              debugPrint('Original street name $id remains enabled: $error');
            }
          }
        }
      }
    } catch (error) {
      // If adding the overlay fails, the improved original labels remain.
      debugPrint('Custom road-name overlay unavailable: $error');
    }
  }

  /// Resolve the nearby named road from currently loaded vector tiles.
  /// Query at most every 6 seconds, never on each animation frame.
  Future<void> _updateCurrentRoad({bool force = false}) async {
    final controller = _map;
    if (controller == null || !_styleReady || !_hasFix ||
        _roadQueryBusy || widget.onRoadNameChanged == null) return;
    final latitude = widget.latitude!, longitude = widget.longitude!;
    if (!_roadQueryGate.shouldQuery(
      now: DateTime.now(), latitude: latitude,
      longitude: longitude, force: force,
    )) return;
    final bearing = widget.speedKmh >= 6 ? _heading : null;
    _roadQueryBusy = true;
    try {
      final features = await controller.querySourceFeatures(
        'openmaptiles', 'transportation_name', null);
      if (!mounted || !identical(_map, controller) || !_styleReady) return;
      final name = nearestRoadName(features,
        latitude: latitude, longitude: longitude,
        bearingDegrees: bearing);
      _roadQueryGate.reportName(name);
      widget.onRoadNameChanged?.call(name);
    } catch (error) {
      debugPrint('Nearby OSM road name unavailable: $error');
    } finally {
      _roadQueryBusy = false;
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _map;
    if (controller == null || !mounted) return;
    final epoch = _styleEpoch.begin();
    _styleReady = true;
    _routeRenderTimer?.cancel();
    _routeRenderTimer = null;
    _lastNativeRouteUpload = null;
    _routeReady = false;
    _arrowReady = false;
    _lastRouteCount = -1;
    _lastRoutePoint = null;
    _cameraGate.reset();
    _visualCamera.reset();
    _roadQueryGate.reset();
    await _enhanceRoadStyle(controller, epoch);
    if (!_styleActive(controller, epoch)) return;
    if (!widget.flat2D) {
      // Both OpenFreeMap Liberty and Dark use the OpenMapTiles "building"
      // vector source layer. Where OSM has no height, a modest 9m extrusion
      // is an illustration, not a measured real-world building height.
      try {
        await controller.addFillExtrusionLayer(
          'openmaptiles',
          'ttx-3d-buildings',
          gl.FillExtrusionLayerProperties(
            fillExtrusionColor: widget.dark ? '#465876' : '#b4afa5',
            fillExtrusionOpacity: widget.dark ? 0.72 : 0.88,
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
    }
    if (!_styleActive(controller, epoch)) return;
    await _installReadableRoadLabels(controller, epoch);
    if (!_styleActive(controller, epoch)) return;
    try {
      await controller.addGeoJsonSource('ttx-route', _routeGeoJson());
      if (!_styleActive(controller, epoch)) return;
      await controller.addLineLayer(
        'ttx-route',
        'ttx-route-line',
        const gl.LineLayerProperties(
          lineColor: '#00C2FF',
          lineWidth: 5.0,
          lineOpacity: 0.9,
        ),
      );
      if (!_styleActive(controller, epoch)) return;
      _routeReady = true;
      _lastRouteCount = widget.routePoints.length;
      _lastRoutePoint = widget.routePoints.isEmpty
          ? null : widget.routePoints.last;
      _lastNativeRouteUpload = DateTime.now();
    } catch (error) {
      debugPrint('3D route layer not available: $error');
    }
    // The arrow is anchored at the true WGS84 GPS fix. The camera can be
    // aimed ahead of the car independently without changing the GPS position.
    try {
      final image = await _cachedArrowImage();
      if (!_styleActive(controller, epoch)) return;
      await controller.addImage('ttx-3d-navigation-arrow', image);
      if (!_styleActive(controller, epoch)) return;
      await controller.addGeoJsonSource('ttx-gps-arrow-position',
        gpsArrowGeoJson(widget.latitude, widget.longitude, _heading));
      if (!_styleActive(controller, epoch)) return;
      await controller.addSymbolLayer(
        'ttx-gps-arrow-position', 'ttx-gps-arrow',
        const gl.SymbolLayerProperties(
          iconImage: 'ttx-3d-navigation-arrow',
          iconSize: 0.42,
          iconAnchor: 'center',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          // A world-relative GPS heading stays correct during map rotation.
          iconRotationAlignment: 'map',
          iconPitchAlignment: 'viewport',
          iconRotate: ['get', 'heading'],
        ),
      );
      if (!_styleActive(controller, epoch)) return;
      _arrowReady = true;
      unawaited(_refreshArrow());
    } catch (error) {
      debugPrint('GPS navigation arrow layer unavailable: $error');
    }
    if (_styleActive(controller, epoch)) {
      _moveToCar(force: true);
      unawaited(_updateCurrentRoad(force: true));
    }
  }

  @override
  void dispose() {
    _styleEpoch.dispose();
    _routeRenderTimer?.cancel();
    _routeRenderTimer = null;
    _routeGeometry.reset();
    _map = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    // Pointer listener is compatible with MapLibre 0.27.1, which does not
    // yet expose onCameraMoveStarted/CameraMoveReason in the widget.
    Listener(
      onPointerDown: (_) => _followCar = false,
      child: gl.MapLibreMap(
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
      onMapCreated: (controller) {
        if (!identical(_map, controller)) _styleEpoch.invalidate();
        _map = controller;
      },
      onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
    ),
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

/// Rendered once per app process and reused across 2D vector fallback,
/// 3D mode, and day/night style changes to avoid repeated PNG encoding.
Future<Uint8List>? _navigationArrowCache;

Future<Uint8List> _cachedArrowImage() {
  final existing = _navigationArrowCache;
  if (existing != null) return existing;
  final pending = _paintArrowImage();
  _navigationArrowCache = pending;
  // If rendering fails (for example during graphics context loss), a
  // later style reload should retry rather than cache a permanent failure.
  pending.then<void>((_) {}, onError: (Object error) {
    if (identical(_navigationArrowCache, pending)) {
      _navigationArrowCache = null;
    }
  });
  return pending;
}

/// Shaded bitmap billboard, not a physical 3D mesh.
Future<Uint8List> _paintArrowImage() async {
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
