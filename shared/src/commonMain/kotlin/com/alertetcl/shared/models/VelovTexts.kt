package com.alertetcl.shared.models

import kotlin.math.roundToInt

/**
 * Les mots des comptes Vélo'v, partagés par iOS et Android. Ce qui est compté prend le nom du filtre :
 * vélos, classiques, électriques ou places, au singulier jusqu'à 1.
 */
object VelovTexts {
    /** Le nom de ce que compte [filter], accordé avec [count] : « vélos », « classique », « places ». */
    fun unit(filter: VelovFilter, count: Int): String {
        val one = when (filter) {
            VelovFilter.ALL -> "vélo"
            VelovFilter.MECHANICAL -> "classique"
            VelovFilter.ELECTRIC -> "électrique"
            VelovFilter.STANDS -> "place"
        }
        return if (count > 1) one + "s" else one
    }

    /** « 14 vélos », « 1 classique », « 0 place » */
    fun count(count: Int, filter: VelovFilter): String = "$count ${unit(filter, count)}"

    /** Une fourchette prévue : « 7 à 17 vélos », ou « 12 vélos » quand ses deux bornes s'arrondissent au même nombre. */
    internal fun range(low: Double, high: Double, filter: VelovFilter): String {
        val from = low.roundToInt()
        val to = high.roundToInt()
        return if (from == to) count(from, filter) else "$from à $to ${unit(filter, to)}"
    }

    /**
     * Ce que vaut la fourchette : « 8 fois sur 10 », d'après la part des cas ([coverage], 0 à 1) où le
     * robot a vu la réalité y tomber. Null quand il ne l'a pas mesurée ; jamais « 10 fois sur 10 ».
     */
    internal fun reliability(coverage: Double?): String? =
        coverage?.let { "${(it * 10).roundToInt().coerceAtMost(9)} fois sur 10" }

    /** Début de la phrase qui annonce une période où l'on ne trouve presque jamais ce que compte [filter]. */
    internal fun shortage(filter: VelovFilter): String = when (filter) {
        VelovFilter.ALL -> "Souvent vide"
        VelovFilter.MECHANICAL -> "Souvent sans classique"
        VelovFilter.ELECTRIC -> "Souvent sans électrique"
        VelovFilter.STANDS -> "Souvent pleine"
    }
}
