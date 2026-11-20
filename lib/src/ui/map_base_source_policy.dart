/// 2D map-source selection. `offlineSigns` is a coordinate canvas and
/// displays local GPS/route/sign references, NOT an offline road basemap.
/// It does not request any raster/vector map tile.
enum Map2DBaseSource {
  raster,
  vector,
  offlineSigns;

  Map2DBaseSource get next => switch (this) {
    Map2DBaseSource.raster => Map2DBaseSource.vector,
    Map2DBaseSource.vector => Map2DBaseSource.offlineSigns,
    Map2DBaseSource.offlineSigns => Map2DBaseSource.raster,
  };

  bool get fetchesRasterTiles => this == Map2DBaseSource.raster;
  bool get usesVectorStyle => this == Map2DBaseSource.vector;
  bool get referenceOnly => this == Map2DBaseSource.offlineSigns;

  String get sourceDescription => switch (this) {
    Map2DBaseSource.raster => 'OSM raster trực tuyến',
    Map2DBaseSource.vector => 'OpenFreeMap vector trực tuyến',
    Map2DBaseSource.offlineSigns =>
      'Chỉ GPS và biển báo · không có bản đồ nền',
  };
}


/// Single-use permission to fall back from an automatically selected
/// network vector style to the local sign-only canvas.
///
/// Timekeeping is owned by the map widget, not this class. A stale timeout
/// must never override a recovered style or a manual map-source selection.
class VectorStyleRecoveryGate {
  int _epoch = 0;
  int? _pending;

  int arm() {
    final ticket = ++_epoch;
    _pending = ticket;
    return ticket;
  }

  bool get pending => _pending != null;

  /// Returns true at most once for the current unresolved style attempt.
  bool consumeTimeout(int ticket) {
    if (_pending != ticket) return false;
    _pending = null;
    ++_epoch;
    return true;
  }

  /// Called after a protected style loads OR on any manual/mode change.
  void cancel() {
    _pending = null;
    ++_epoch;
  }
}
