package com.alertetcl.android

import android.app.Application
import com.alertetcl.shared.platform.AndroidBundleSetup

class AlerteTCLApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AndroidBundleSetup.install(this)
    }
}
