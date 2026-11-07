package vn.thanhtaxixanh.ttx_aataximeter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/// Phone ↔ native read-only snapshot mirror. Authoritative trip data is SQLite.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "vn.thanhtaxixanh.ttx_aataximeter/car"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishState" -> {
                    val map = call.arguments as? Map<*, *>
                    if (map == null) {
                        result.error("INVALID_STATE", "Expected Map", null)
                    } else {
                        val values = map.entries.associate {
                            it.key.toString() to it.value
                        }
                        CarStateStore.write(applicationContext,
                            JSONObject(values).toString())
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
