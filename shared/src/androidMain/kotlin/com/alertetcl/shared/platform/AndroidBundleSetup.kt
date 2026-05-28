package com.alertetcl.shared.platform

import android.content.Context
import com.alertetcl.shared.util.AppLogger

object AndroidBundleSetup {
    fun install(context: Context) {
        BundledResources.loader = { name ->
            try {
                context.assets.open("$name.json").bufferedReader().use { it.readText() }
            } catch (e: Throwable) {
                AppLogger.error("Failed to load bundled asset '$name.json'", e)
                null
            }
        }
    }
}
