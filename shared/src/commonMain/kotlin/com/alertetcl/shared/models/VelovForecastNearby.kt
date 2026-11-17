package com.alertetcl.shared.models

import com.alertetcl.shared.geo.fastDistance2D
import kotlin.math.max
import kotlin.math.roundToInt

/** Une station voisine où l'on a de bonnes chances de trouver ce que la station de la fiche risque de ne pas avoir. */
data class VelovForecastNeighbour(
    val station: VelovStation,
    /** « 6 min à pied · 0 à 9 vélos » */
    val detail: String,
    val chance: VelovChance
)

/**
 * « Plus sûr à côté » : parmi les stations ouvertes que le modèle connaît à moins de [RADIUS_METERS] à
 * vol d'oiseau de [station], les [MAX_SHOWN] plus proches où la chance est au moins « probable » à la
 * même échéance et pour le même filtre.
 *
 * Rien n'est calculé d'avance : une échéance demandée coûte la probabilité de chaque voisine, puis la
 * fourchette des seules retenues (environ une milliseconde au cœur de Lyon, où une station en a
 * jusqu'à 27), et la réponse est gardée. À n'appeler que d'un seul fil, celui de la fiche.
 */
internal class VelovForecastNearby(
    private val model: VelovForecastModel,
    station: VelovStation,
    stations: List<VelovStation>,
    private val originEpochMs: Long
) {
    private class Candidate(val station: VelovStation, val meters: Double)

    private val candidates: List<Candidate> = stations
        .filter { it.id != station.id && it.open && model.knows(it.id) }
        .map { Candidate(it, fastDistance2D(station.coordinate, it.coordinate)) }
        .filter { it.meters < RADIUS_METERS }
        .sortedBy { it.meters }

    private val answers = HashMap<Pair<Int, VelovFilter>, List<VelovForecastNeighbour>>()

    fun saferAt(step: Int, filter: VelovFilter): List<VelovForecastNeighbour> = answers.getOrPut(step to filter) {
        val chances = model.chances(candidates.map { it.station }, originEpochMs, step, filter)
        val safe = candidates.filterIndexed { rank, _ -> VelovChance.of(chances[rank]).level.isSafe }.take(MAX_SHOWN)
        val outlooks = model.outlooks(safe.map { it.station }, originEpochMs, step, filter)
        safe.mapIndexed { rank, candidate ->
            val outlook = outlooks[rank]
            VelovForecastNeighbour(candidate.station, "${walk(candidate.meters)} · ${VelovTexts.range(outlook.range, filter)}", VelovChance.of(outlook.probability))
        }
    }

    companion object {
        const val RADIUS_METERS = 600.0
        const val MAX_SHOWN = 2

        /** Un trajet à pied fait environ 1,3 fois le vol d'oiseau, à 80 m par minute. */
        private const val DETOUR = 1.3
        private const val METERS_PER_MINUTE = 80.0

        /** « 6 min à pied », jamais moins d'une minute. */
        fun walk(meters: Double): String = "${max(1, (meters * DETOUR / METERS_PER_MINUTE).roundToInt())} min à pied"
    }
}
