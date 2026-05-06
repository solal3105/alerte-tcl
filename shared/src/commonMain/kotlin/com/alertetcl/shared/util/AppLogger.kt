package com.alertetcl.shared.util

/**
 * Logger commun (appelable depuis tous les targets).
 * L'implémentation par défaut écrit sur println — chaque plateforme peut la
 * remplacer (Logcat sur Android, NSLog sur iOS).
 */
object AppLogger {
    var enabled: Boolean = true
    var sink: (String) -> Unit = { println(it) }

    fun debug(message: String) {
        if (enabled) sink(message)
    }

    fun warn(message: String) {
        if (enabled) sink("⚠️ $message")
    }

    fun error(message: String, throwable: Throwable? = null) {
        if (enabled) {
            sink("❌ $message")
            throwable?.printStackTrace()
        }
    }
}
