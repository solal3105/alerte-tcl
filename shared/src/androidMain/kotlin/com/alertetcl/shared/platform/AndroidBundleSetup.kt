package com.alertetcl.shared.platform

import android.content.Context

object AndroidBundleSetup {
    fun install(context: Context) {
        BundledResources.loader = { name ->
            try {
                context.assets.open("$name.json").bufferedReader().use { it.readText() }
            } catch (_: Throwable) { null }
        }
    }
}
