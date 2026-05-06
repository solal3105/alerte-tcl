package com.alertetcl.shared.platform

/**
 * Accès aux ressources JSON bundlées.
 * L'app native enregistre une implémentation au démarrage via [AndroidBundleSetup]
 * (Android) ou [IosBundleSetup] (iOS).
 */
object BundledResources {
    var loader: (String) -> String? = { null }
    fun loadJsonString(name: String): String? = loader(name)
}
