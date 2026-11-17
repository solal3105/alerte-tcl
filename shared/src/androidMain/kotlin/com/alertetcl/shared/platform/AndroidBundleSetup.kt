package com.alertetcl.shared.platform

import android.content.Context
import com.alertetcl.shared.util.AppLogger

/** Branche au démarrage ce que le module partagé attend d'Android : les ressources embarquées et le dossier de cache. */
object AndroidBundleSetup {
    fun install(context: Context) {
        LocalFilesDirectory.use(context.cacheDir)
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
