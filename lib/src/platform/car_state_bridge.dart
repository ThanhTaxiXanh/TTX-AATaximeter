import 'package:flutter/services.dart';
import '../core/taximeter_engine.dart';

/// Limits best-effort native display snapshots without affecting SQLite,
/// distance, elapsed time, or the authoritative taximeter.
class CarStatePublishGate {
  CarStatePublishGate({
    this.minimumInterval = const Duration(seconds: 10),
  });

  final Duration minimumInterval;
  DateTime? _lastPublishedAt;
  String? _lastStatus;
  bool? _lastInterrupted;

  bool shouldPublish(DateTime now, {
    required String status,
    required bool interrupted,
  }) {
    final last = _lastPublishedAt;
    if (last == null || now.isBefore(last)) return true;
    if (_lastStatus != status || _lastInterrupted != interrupted) return true;
    return now.difference(last) >= minimumInterval;
  }

  void markPublished(DateTime now, {
    required String status,
    required bool interrupted,
  }) {
    _lastPublishedAt = now;
    _lastStatus = status;
    _lastInterrupted = interrupted;
  }
}

/// Best-effort display mirror. Never an authoritative billing store.
/// The experimental Android Auto host is not registered in the current APK.
class CarStateBridge {
  static const _channel =
      MethodChannel('vn.thanhtaxixanh.ttx_aataximeter/car');
  static final CarStatePublishGate _gate = CarStatePublishGate();

  static Future<void> publish(TaximeterEngine meter) async {
    final now = DateTime.now();
    final status = meter.status.name;
    final interrupted = meter.requiresManualResume;
    if (!_gate.shouldPublish(now,
        status: status, interrupted: interrupted)) return;

    try {
      await _channel.invokeMethod<void>('publishState', <String, dynamic>{
        'status': status,
        'interrupted': interrupted,
        'fareVnd': meter.totalFare.round(),
        'distanceKm': meter.distanceKm,
        'elapsedSeconds': meter.elapsedSeconds,
        'waitingSeconds': meter.waitingSeconds,
        'speedKmh': meter.speedKmh,
        'timestampMs': now.millisecondsSinceEpoch,
      });
      // Only successful writes advance the gate; errors can retry.
      _gate.markPublished(now, status: status, interrupted: interrupted);
    } on MissingPluginException {
      // Runs on other platforms / when the native host is not configured.
    } on PlatformException {
      // A disconnected display must never interrupt an ongoing fare.
    }
  }
}
