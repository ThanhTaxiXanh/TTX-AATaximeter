package vn.thanhtaxixanh.ttx_aataximeter

import android.content.Intent
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/**
 * EXPERIMENTAL native scaffold. Intentionally NOT registered in Manifest:
 * a standalone taximeter has no approved Android Auto car-app category.
 * The app cannot be discovered by Android Auto until eligibility is resolved.
 */
class TtxCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator =
        HostValidator.Builder(applicationContext)
            .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
            .build()

    override fun onCreateSession(): Session = TtxCarSession()
}

class TtxCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen =
        TtxCarScreen(carContext)
}
