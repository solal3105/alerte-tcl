package com.alertetcl.android

import android.app.Application
import com.alertetcl.android.notifications.AlertWorkerScheduler
import com.alertetcl.android.notifications.NotificationChannels
import com.alertetcl.shared.platform.AndroidBundleSetup
import org.maplibre.android.MapLibre

class AlerteTCLApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapLibre.getInstance(this)
        AndroidBundleSetup.install(this)
        NotificationChannels.ensureChannels(this)
        AlertWorkerScheduler.schedule(this)
    }
}
