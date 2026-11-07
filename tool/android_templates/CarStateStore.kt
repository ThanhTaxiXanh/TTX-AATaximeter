package vn.thanhtaxixanh.ttx_aataximeter

import android.content.Context

/** Untrusted, best-effort display state; not a fare ledger. */
object CarStateStore {
    private const val FILE = "ttx_car_display_state"
    private const val KEY = "last_snapshot"

    fun write(context: Context, json: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit().putString(KEY, json).apply()
    }

    fun read(context: Context): String? =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY, null)
}
