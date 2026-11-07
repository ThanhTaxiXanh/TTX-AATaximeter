/// Safety gate for metering against gaps in trustworthy GPS telemetry.
///
/// This is NOT proof that an Android foreground service is alive. The caller
/// must also have a subscribed stream, permission and location services.
class LocationTrackingPolicy {
  LocationTrackingPolicy({
    this.acquireTimeout = const Duration(seconds: 30),
    this.gpsGapTimeout = const Duration(seconds: 12),
  });

  final Duration acquireTimeout;
  final Duration gpsGapTimeout;

  DateTime? _startedAt;
  DateTime? _lastTrustedFixAt;

  DateTime? get lastTrustedFixAt => _lastTrustedFixAt;
  bool get hasTrustedFix => _lastTrustedFixAt != null;
  bool get isMonitoring => _startedAt != null;

  void begin(DateTime time) {
    _startedAt = time;
    _lastTrustedFixAt = null;
  }

  /// Always timestamp with the local reception time after validating
  /// coordinate, accuracy and the fix's embedded timestamp.
  void acceptedFix(DateTime receivedAt) {
    final started = _startedAt;
    if (started == null || receivedAt.isBefore(started)) return;
    final previous = _lastTrustedFixAt;
    if (previous == null || receivedAt.isAfter(previous)) {
      _lastTrustedFixAt = receivedAt;
    }
  }

  bool hasRecentFix(DateTime now) {
    final last = _lastTrustedFixAt;
    return last != null && !now.isBefore(last) &&
        now.difference(last) <= gpsGapTimeout;
  }

  bool get hasFix => _lastTrustedFixAt != null;

  bool shouldSuspend(DateTime now) {
    final start = _startedAt;
    if (start == null) return false;
    final last = _lastTrustedFixAt;
    // An unexpected wall-clock reversal invalidates the elapsed-time proof.
    // Do not resume charging until the driver re-establishes GPS monitoring.
    if (now.isBefore(start)) return true;
    if (last == null) return now.difference(start) > acquireTimeout;
    if (now.isBefore(last)) return true;
    return now.difference(last) > gpsGapTimeout;
  }

  bool canLeaveForeground(DateTime now, {required bool streamSubscribed}) =>
      streamSubscribed && hasRecentFix(now);

  void clear() {
    _startedAt = null;
    _lastTrustedFixAt = null;
  }
}
