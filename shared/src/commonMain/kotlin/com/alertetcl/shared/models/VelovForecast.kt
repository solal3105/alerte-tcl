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

    /** Ce que la station compte au départ pour [filter]. */
    fun count(filter: VelovFilter): Int = when (filter) {
        VelovFilter.ALL -> bikes
        VelovFilter.MECHANICAL -> mechanical
        VelovFilter.ELECTRIC -> electric
        VelovFilter.STANDS -> docks
    }

    /** Ramène un nombre de vélos ou de places entre zéro et la capacité (comptée pour 1 au moins, comme à l'entraînement). */
    fun bounded(count: Double): Double = min(max(1, capacity).toDouble(), max(0.0, count))

    /**
     * Places libres quand il y a [bikes] vélos : ce qui n'est pas occupé par un vélo est libre, donc
     * `places de départ + vélos de départ − vélos prévus`, borné comme les vélos. Ce calcul suppose que
     * le nombre de bornes hors service ne bouge pas d'ici l'échéance ; le robot hebdomadaire mesure
     * que la fourchette ainsi déduite reste honnête.
     */
    fun docksLeftBy(bikes: Double): Double = bounded(docks + this.bikes - bikes)
}

/** Ce qui est prévu à une échéance pour ce que compte un [VelovFilter] : vélos, classiques, électriques ou places libres. */
data class VelovForecastOutlook(
    /** Niveaux des déciles (10, 30, 50, 70, 90), dans l'ordre de [deciles]. */
    val levels: List<Int>,
    /** Nombre prévu à chacun de ces niveaux, croissant, entre zéro et la capacité. */
    val deciles: List<Double>,
    /** Probabilité d'en trouver au moins un. */
    val probability: Double
) {
    /** Le nombre prévu au décile [level], un des niveaux de [levels]. */
    fun at(level: Int): Double = deciles[levels.indexOf(level)]

    companion object {
        // Niveaux lus par l'affichage, que tout modèle accepté fournit : la fourchette large (celle du
        // « N fois sur 10 »), la fourchette serrée du graphique et la valeur la plus probable.
        const val LOW = 10
        const val MID_LOW = 30
        const val MEDIAN = 50
        const val MID_HIGH = 70
        const val HIGH = 90
        val SHOWN_LEVELS = listOf(LOW, MID_LOW, MEDIAN, MID_HIGH, HIGH)
    }
}

/** Ce qui est prévu à une échéance. */
data class VelovForecastStep(
    val bikes: VelovForecastOutlook,
    val mechanical: VelovForecastOutlook,
    val electric: VelovForecastOutlook,
    /** Places libres : leurs déciles sont déduits de ceux des vélos ([VelovForecastState.docksLeftBy]). */
    val docks: VelovForecastOutlook
) {
    fun outlook(filter: VelovFilter): VelovForecastOutlook = when (filter) {
        VelovFilter.ALL -> bikes
        VelovFilter.MECHANICAL -> mechanical
        VelovFilter.ELECTRIC -> electric
        VelovFilter.STANDS -> docks
    }
}

/**
 * Prévision d'une station : [STEP_COUNT] échéances, la première [STEP_MINUTES] minutes après l'heure où
 * l'état de départ a été relevé, la dernière 24 h après.
 */
data class VelovForecast(val state: VelovForecastState, val steps: List<VelovForecastStep>) {
    companion object {
        const val STEP_MINUTES = 15
        const val STEP_COUNT = 96
        const val STEP_MS = STEP_MINUTES * 60_000L
    }
}

/** Ce qu'un marqueur de carte montre d'une station à une échéance : le nombre le plus probable et la probabilité d'en trouver au moins un. */
internal class VelovForecastGlance(val median: Double, val probability: Double)
