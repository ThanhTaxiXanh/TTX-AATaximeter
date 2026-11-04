import 'package:flutter/services.dart';
import '../core/taximeter_engine.dart';

/// Best-effort display mirror. Never an authoritative billing store.
class CarStateBridge {
  static const _channel =
      MethodChannel('vn.thanhtaxixanh.ttx_aataximeter/car');

  static Future<void> publish(TaximeterEngine meter) async {
    try {
      await _channel.invokeMethod<void>('publishState', <String, dynamic>{
        'status': meter.status.name,
        'interrupted': meter.requiresManualResume,
        'fareVnd': meter.totalFare.round(),
        'distanceKm': meter.distanceKm,
        'elapsedSeconds': meter.elapsedSeconds,
        'waitingSeconds': meter.waitingSeconds,
        'speedKmh': meter.speedKmh,
        'timestampMs': DateTime.now().millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // Runs on other platforms / when the native host is not configured.
    } on PlatformException {
      // A disconnected screen must never interrupt an ongoing fare.
    }
  }
}
