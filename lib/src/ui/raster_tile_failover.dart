/// Records failures from the lightweight raster base layer. After repeated
/// errors the UI can render a vector-based OpenFreeMap fallback. This is a
/// presentation-only decision and must not affect the GPS/metering engine.
class RasterTileFailover {
  RasterTileFailover({this.failureThreshold = 3})
      : assert(failureThreshold > 0);

  final int failureThreshold;
  int _failures = 0;
  bool _fallback = false;

  int get failures => _failures;
  bool get useVectorFallback => _fallback;

  /// True exactly when the caller should switch the map source.
  bool recordFailure() {
    if (_fallback) return false;
    _failures++;
    if (_failures < failureThreshold) return false;
    _fallback = true;
    return true;
  }

  /// A manual retry opens a new set of requests to the original tile host.
  void reset() {
    _failures = 0;
    _fallback = false;
  }
}
