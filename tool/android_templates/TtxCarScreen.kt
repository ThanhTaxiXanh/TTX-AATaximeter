package vn.thanhtaxixanh.ttx_aataximeter

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import org.json.JSONObject
import java.util.Locale

/**
 * Read-only template. No driving-sensitive payment/setting dialogs.
 * Rendering is host controlled and not a full Flutter/934x844 layout.
 */
class TtxCarScreen(context: CarContext) : Screen(context) {
    override fun onGetTemplate(): Template {
        val payload = CarStateStore.read(carContext)
        val state = try {
            JSONObject(payload ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        val millis = state.optLong("timestampMs", 0L)
        val ageMs = System.currentTimeMillis() - millis
        val isStale = millis <= 0L || ageMs < 0L || ageMs > 15000L
        val title = if (isStale) {
            "TTX AATaximeter - du lieu cu"
        } else {
            "TTX AATaximeter"
        }
        val fare = state.optInt("fareVnd", 0)
        val distance = state.optDouble("distanceKm", 0.0)
        val interrupted = state.optBoolean("interrupted", false)
        val status = if (isStale) {
            "Mo ung dung tren dien thoai"
        } else if (interrupted) {
            "Tam ngat: can xac nhan tren dien thoai"
        } else {
            when (state.optString("status", "idle")) {
                "running" -> "Dang tinh cuoc"
                "paused" -> "Tam dung"
                "finished" -> "Da ket thuc"
                else -> "Xe trong"
            }
        }
        val pane = Pane.Builder()
            .addRow(Row.Builder()
                .setTitle("Cuoc: $fare VND")
                .build())
            .addRow(Row.Builder()
                .setTitle("Km: " + String.format(
                    Locale.US, "%.2f", distance))
                .build())
            .addRow(Row.Builder()
                .setTitle(status)
                .build())
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle(title)
            .setHeaderAction(Action.APP_ICON)
            .build()
    }
}
