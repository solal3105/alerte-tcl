package com.alertetcl.shared.models

import kotlin.math.roundToInt

/**
 * Les quatre paliers d'une chance de trouver un vélo ou une place à une station Vélo'v. Le mot ne
 * s'accorde pas (« c'est quasi sûr ») : il vaut pour un vélo comme pour une place. Couleurs :
 * `AppColors.velovChance` en texte, `AppColors.velovChanceTrack` sur la piste du curseur.
 */
enum class VelovChanceLevel(val label: String) {
    NEAR_CERTAIN("quasi sûr"),
    LIKELY("probable"),
    UNCERTAIN("incertain"),
    UNLIKELY("peu probable");

    /** Assez sûr pour être conseillé à la place d'une station qui ne l'est pas. */
    val isSafe: Boolean get() = this == NEAR_CERTAIN || this == LIKELY

    /** Sur la carte, où il n'y a que trois couleurs : les deux paliers hauts sont verts. */
    val availability: AvailabilityColor get() = when (this) {
        NEAR_CERTAIN, LIKELY -> AvailabilityColor.GREEN
        UNCERTAIN -> AvailabilityColor.ORANGE
        UNLIKELY -> AvailabilityColor.RED
    }
}

/**
 * Une chance telle qu'elle s'affiche : un pourcentage entier et son palier.
 *
 * Le pourcentage ne dit jamais 0 ni 100 : une prévision n'est pas une certitude. Le palier se lit sur
 * le pourcentage affiché, pas sur la probabilité brute, pour que deux stations qui montrent le même
 * chiffre aient toujours le même mot et la même couleur, sur la fiche comme sur la carte.
 */
data class VelovChance(val percent: Int, val level: VelovChanceLevel) {
    /** « 82 % » */
    val text: String get() = "$percent %"

    companion object {
        private const val NEAR_CERTAIN_FROM = 90
        private const val LIKELY_FROM = 70
        private const val UNCERTAIN_FROM = 40

        fun of(probability: Double): VelovChance {
            val percent = (probability * 100).roundToInt().coerceIn(1, 99)
            val level = when {
                percent >= NEAR_CERTAIN_FROM -> VelovChanceLevel.NEAR_CERTAIN
                percent >= LIKELY_FROM -> VelovChanceLevel.LIKELY
                percent >= UNCERTAIN_FROM -> VelovChanceLevel.UNCERTAIN
                else -> VelovChanceLevel.UNLIKELY
            }
            return VelovChance(percent, level)
        }
    }
}
