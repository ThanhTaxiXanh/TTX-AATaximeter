/// Guards asynchronous MapLibre style installation against reloads and
/// widget disposal. A stale operation must not mark layers ready or trigger
/// a camera/road-name update for a newer style.
class MapStyleEpoch {
  int _revision = 0;
  bool _disposed = false;

  int begin() {
    if (_disposed) throw StateError('Map style owner disposed');
    return ++_revision;
  }

  void invalidate() {
    if (!_disposed) _revision++;
  }

  bool isCurrent(int revision) => !_disposed && revision == _revision;

  void dispose() {
    _disposed = true;
    _revision++;
  }
}
