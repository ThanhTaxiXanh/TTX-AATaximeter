import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/traffic_sign_database.dart';
import '../data/traffic_sign_repository.dart';
import '../domain/traffic_sign.dart';

/// Converts bounded SQLite viewport results into MapLibre GeoJSON.
/// Sign positions and inferred speed values are display-only and never enter
/// the GPS or trip repositories.
Map<String, dynamic> trafficSignFeatureCollection(
    SignViewportResult result) => {
  'type': 'FeatureCollection',
  'features': result.items.map((item) => {
    'type': 'Feature',
    'id': item.signId,
    'geometry': {
      'type': 'Point',
      'coordinates': [item.longitude, item.latitude],
    },
    'properties': {
      'sign_id': item.signId,
      'count': item.count,
      if (item.speedKmhInferred != null)
        'speed_kmh_inferred': item.speedKmhInferred,
    },
  }).toList(growable: false),
};

/// MapLibre-native traffic-sign layer. It reads the same owner-controlled
/// preferences and the same read-only, RTree-backed SQLite repository as the
/// existing Flutter Map 2D layer. Queries run only after camera idle.
class TrafficSignMapLibreOverlay {
  TrafficSignMapLibreOverlay(this._controller);

  static const sourceId = 'ttx-traffic-signs-source';
  static const layerId = 'ttx-traffic-signs-layer';
  static const _enabledKey = 'ttx_signs_layer_enabled_v1';
  static const _speedKey = 'ttx_signs_speed_only_v1';
  static const _typeKey = 'ttx_signs_type_code_v1';

  final gl.MapLibreMapController _controller;
  TrafficSignRepository? _repository;
  TrafficSignFilter _filter = const TrafficSignFilter();
  Timer? _queryTimer;
  int _epoch = 0;
  bool _installed = false;
  bool _disposed = false;

  Future<void> install() async {
    if (_disposed || _installed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _filter = TrafficSignFilter(
        enabled: prefs.getBool(_enabledKey) ?? false,
        speedOnly: prefs.getBool(_speedKey) ?? false,
        typeCode: prefs.getInt(_typeKey),
      );
      if (!_filter.enabled) return;

      final repository = await TrafficSignDatabase.openOptional();
      if (_disposed || repository == null) return;
      _repository = repository;

      await _controller.addGeoJsonSource(
        sourceId,
        trafficSignFeatureCollection(SignViewportResult.empty),
      );
      if (_disposed) return;
      await _controller.addCircleLayer(
        sourceId,
        layerId,
        gl.CircleLayerProperties(
          circleRadius: [
            'interpolate', ['linear'], ['zoom'],
            5, 3.0, 10, 5.0, 15, 7.0, 19, 9.0,
          ],
          circleColor: [
            'case', ['>', ['get', 'count'], 1],
            '#00A6D6', '#00C8F0',
          ],
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 1.2,
          circleOpacity: 0.96,
        ),
        minzoom: 8,
        maxzoom: 22,
        enableInteraction: false,
      );
      _installed = true;
      await refresh();
    } catch (error) {
      // Traffic-sign data is optional; a failure must not block map, GPS,
      // trip recovery, or the taximeter.
      debugPrint('MapLibre traffic-sign layer unavailable: $error');
    }
  }

  void scheduleRefresh() {
    if (_disposed || !_installed || _repository == null) return;
    _queryTimer?.cancel();
    final epoch = ++_epoch;
    _queryTimer = Timer(const Duration(milliseconds: 180), () {
      if (!_disposed && epoch == _epoch) {
        unawaited(refresh());
      }
    });
  }

  Future<void> refresh() async {
    final repository = _repository;
    if (_disposed || !_installed || repository == null) return;
    final epoch = ++_epoch;
    try {
      final bounds = await _controller.getVisibleRegion();
      if (_disposed || epoch != _epoch) return;
      final viewport = SignViewport(
        west: bounds.southwest.longitude,
        south: bounds.southwest.latitude,
        east: bounds.northeast.longitude,
        north: bounds.northeast.latitude,
      );
      if (!viewport.isValid) return;
      final result = await repository.viewport(viewport, _filter);
      if (_disposed || epoch != _epoch) return;
      await _controller.setGeoJsonSource(
        sourceId, trafficSignFeatureCollection(result));
    } catch (error) {
      if (!_disposed) {
        debugPrint('MapLibre traffic-sign viewport query failed: $error');
      }
    }
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _queryTimer?.cancel();
    _queryTimer = null;
  }
}
