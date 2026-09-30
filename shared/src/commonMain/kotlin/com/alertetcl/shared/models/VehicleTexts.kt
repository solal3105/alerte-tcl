package com.alertetcl.shared.models

import kotlin.math.abs

/**
 * Les mots d'un véhicule, partagés par iOS et Android.
 *
 * Un écart à l'horaire s'écrit toujours avec son sens (« 2 min de retard », « 3 min d'avance ») et
 * c'est lui seul qui passe en orange. Sous une minute, l'écart n'est pas nommable : le véhicule est
 * annoncé à l'heure, sans chiffre.
 */
object VehicleTexts {
    /** En deçà de cet écart, en secondes, le véhicule est annoncé à l'heure. */
    private const val TOLERANCE_SECONDS = 60

    /** Retard ou avance d'au moins une minute. */
    fun isOffSchedule(delaySeconds: Int): Boolean = abs(delaySeconds) > TOLERANCE_SECONDS

    /** La ponctualité en une phrase : « 2 min de retard », « 3 min d'avance », « À l'heure ». */
    fun punctuality(delaySeconds: Int): String {
        if (!isOffSchedule(delaySeconds)) return "À l'heure"
        val minutes = (abs(delaySeconds) + 30) / 60
        return "$minutes min ${if (delaySeconds > 0) "de retard" else "d'avance"}"
    }

    /** « Prochain arrêt Bellecour à 22:53 », ou « Arrive à Bellecour » sans heure à venir. */
    fun nextStop(stopName: String, time: String?): String =
        if (time != null) "Prochain arrêt $stopName à $time" else "Arrive à $stopName"
}
