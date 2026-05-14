package com.alertetcl.android

import android.app.Application
import com.alertetcl.android.notifications.AlertWorkerScheduler
import com.alertetcl.android.notifications.NotificationChannels
import com.alertetcl.shared.platform.AndroidBundleSetup
import com.alertetcl.shared.platform.BundledResources
import com.alertetcl.shared.services.SiriLiteService
import org.json.JSONArray
import org.maplibre.android.MapLibre

class AlerteTCLApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapLibre.getInstance(this)
        AndroidBundleSetup.install(this)
        SiriLiteService.shared.stopNameLookup = buildStopNamesMap()::get
        NotificationChannels.ensureChannels(this)
        AlertWorkerScheduler.schedule(this)
    }

    private fun buildStopNamesMap(): Map<String, String> {
        val json = BundledResources.loadJsonString("tcl_stops") ?: return emptyMap()
        return try {
            val arr = JSONArray(json)
            buildMap {
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    put(obj.getString("id"), obj.getString("name"))
                }
            }
        } catch (_: Throwable) { emptyMap() }
    }
}
