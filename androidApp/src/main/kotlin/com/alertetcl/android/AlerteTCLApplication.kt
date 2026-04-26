package com.alertetcl.android

import android.app.Application
import com.alertetcl.android.notifications.AlertWorkerScheduler
import com.alertetcl.android.notifications.NotificationChannels
import com.alertetcl.shared.platform.AndroidBundleSetup

class AlerteTCLApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AndroidBundleSetup.install(this)
        NotificationChannels.ensureChannels(this)
        AlertWorkerScheduler.schedule(this)
    }
}
