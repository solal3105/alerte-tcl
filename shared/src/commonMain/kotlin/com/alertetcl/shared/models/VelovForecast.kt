package com.alertetcl.shared.models

import kotlin.math.max
import kotlin.math.min

/** État d'une station au moment où part une prévision. */
data class VelovForecastState(
    val electric: Int,
    val mechanical: Int,
    /** Places libres pour rendre un vélo. */
    val docks: Int,
    val capacity: Int
) {
    constructor(station: VelovStation) : this(station.ebikes, station.mechanicalBikes, station.stands, station.capacity)

    val bikes: Int get() = electric + mechanical

    /** Ramène un nombre de vélos ou de places entre zéro et la capacité (comptée pour 1 au moins, comme à l'entraînement). */
    fun bounded(count: Double): Double = min(max(1, capacity).toDouble(), max(0.0, count))
}

/** Ce qui est prévu à une échéance. */
data class VelovForecastStep(
    /** Heure visée (epoch, millisecondes). */
    val timeEpochMs: Long,
    /** Nombre de vélos à chaque niveau de [VelovForecast.deciles], croissant, entre zéro et la capacité. */
    val bikeDeciles: List<Double>,
    /** Probabilité de trouver au moins un vélo. */
    val bikeProbability: Double,
    /** Probabilité de trouver au moins une place libre. */
    val dockProbability: Double,
    /** Part attendue de vélos électriques parmi les vélos présents. */
    val electricShare: Double
)

/** Prévision d'une station : [STEP_COUNT] échéances de [STEP_MINUTES] minutes, jusqu'à 24 h après l'état de départ. */
data class VelovForecast(
    val state: VelovForecastState,
    /** Niveaux des déciles (10, 20… 90), dans l'ordre de [VelovForecastStep.bikeDeciles]. */
    val deciles: List<Int>,
    val steps: List<VelovForecastStep>
) {
    /**
     * Places libres déduites des déciles de vélos : ce qui n'est pas occupé par un vélo est libre,
     * donc `places de départ + vélos de départ − vélos prévus`, borné comme les vélos. Beaucoup de vélos
     * font peu de places : l'ordre est retourné pour rester croissant, et la valeur de rang `i` est au
     * niveau `100 − deciles[dernier − i]` (les mêmes niveaux tant qu'ils sont symétriques).
     *
     * Ce calcul suppose que le nombre de bornes hors service ne bouge pas d'ici l'échéance ; le robot
     * hebdomadaire mesure que la fourchette ainsi déduite reste honnête.
     */
    fun derivedDockDeciles(step: VelovForecastStep): List<Double> =
        step.bikeDeciles.asReversed().map { state.bounded(state.docks + state.bikes - it) }

    companion object {
        const val STEP_MINUTES = 15
        const val STEP_COUNT = 96
    }
}
