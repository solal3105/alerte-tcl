package com.alertetcl.shared.util

// kotlin.concurrent.Volatile : variante multiplateforme — le @Volatile implicite
// n'existe que sur JVM et cassait la compilation des targets iOS.
import kotlin.concurrent.Volatile

/**
 * Logger commun (appelable depuis tous les targets).
 * L'implémentation par défaut écrit sur println — chaque plateforme peut la
 * remplacer (Logcat sur Android, NSLog sur iOS).
 */
object AppLogger {
    @Volatile var enabled: Boolean = true
    @Volatile var sink: (String) -> Unit = { println(it) }

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
