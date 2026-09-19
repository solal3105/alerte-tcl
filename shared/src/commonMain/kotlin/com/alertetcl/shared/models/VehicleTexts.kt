package com.alertetcl.shared.models

import kotlin.math.abs

/**
 * Les mots de la fiche d'un véhicule, partagés par iOS et Android.
 *
 * La ponctualité se lit en deux morceaux, un chiffre et ce qu'il veut dire (« 2 min », « de retard »),
 * pour qu'un écart ne soit jamais montré sans être nommé. Sous une minute, l'écart n'est pas nommable :
 * le véhicule est annoncé à l'heure, sans chiffre.
 */
object VehicleTexts {
    /** En deçà de cet écart, en secondes, le véhicule est annoncé à l'heure. */
    const val TOLERANCE_SECONDS = 60

    fun isDelayed(delaySeconds: Int): Boolean = delaySeconds > TOLERANCE_SECONDS
    fun isEarly(delaySeconds: Int): Boolean = delaySeconds < -TOLERANCE_SECONDS
    private fun isOnTime(delaySeconds: Int): Boolean = !isDelayed(delaySeconds) && !isEarly(delaySeconds)

    /** Le chiffre mis en avant : « 2 min », ou « à l'heure » quand il n'y a pas d'écart à montrer. */
    fun punctualityAmount(delaySeconds: Int): String =
        if (isOnTime(delaySeconds)) "à l'heure" else "${(abs(delaySeconds) + 30) / 60} min"

    /** Ce que ce chiffre veut dire, écrit juste en dessous. */
    fun punctualityCaption(delaySeconds: Int): String = when {
        isDelayed(delaySeconds) -> "de retard"
        isEarly(delaySeconds) -> "d'avance"
        else -> "ponctualité"
    }

    /** La phrase entière, pour une pastille : « 2 min de retard », « À l'heure ». */
    fun punctuality(delaySeconds: Int): String =
        if (isOnTime(delaySeconds)) "À l'heure"
        else "${punctualityAmount(delaySeconds)} ${punctualityCaption(delaySeconds)}"

    /** Légende de l'heure d'arrivée au prochain arrêt : « arrivée à Bellecour ». */
    fun arrivalCaption(stopName: String): String = "arrivée à $stopName"
}
