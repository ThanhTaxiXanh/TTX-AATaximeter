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
