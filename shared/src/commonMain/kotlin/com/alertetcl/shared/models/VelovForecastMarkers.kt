package com.alertetcl.shared.models

import kotlin.math.roundToInt

/**
 * Le marqueur d'une station sur la carte quand le curseur d'heure a quitté « Maintenant » : le nombre
 * le plus probable de ce que compte le filtre, et la couleur de la chance d'en trouver au moins un
 * (verte dès « probable », orange « incertain », rouge « peu probable »).
 */
data class VelovForecastMarker(val station: VelovStation, val count: Int, val availability: AvailabilityColor)

/**
 * Les marqueurs prévus de toutes les stations, échéance par échéance, pour que le curseur de la carte
 * réponde tout de suite quand on revient sur une échéance déjà vue.
 *
 * Une station fermée ou que le modèle ne connaît pas n'a pas de marqueur : l'application ne montre pas
 * une estimation qu'elle n'a pas, et un marqueur gris sans nombre dirait « fermée », ce qu'elle ne sait
 * pas davantage pour demain. La station réapparaît dès que le curseur revient à « Maintenant ».
 *
 * Ne sont gardées que les échéances d'un même relevé des stations, d'une même heure de départ et d'un
 * même filtre (96 listes au plus) : tout est oublié dès que l'un des trois change. À n'appeler que
 * d'un seul fil à la fois.
 */
internal class VelovForecastMarkers(private val model: VelovForecastModel) {
    private var stations: List<VelovStation> = emptyList()
    private var originEpochMs = 0L
    private var filter = VelovFilter.ALL

    /** Les stations qui ont une prévision, parmi [stations]. */
    private var forecastable: List<VelovStation> = emptyList()
    private val bySteps = HashMap<Int, List<VelovForecastMarker>>()

    /** Les marqueurs à l'échéance [step] ; aucun hors de 1 à 96, l'échéance 0 étant l'état réel. */
    fun at(stations: List<VelovStation>, originEpochMs: Long, step: Int, filter: VelovFilter): List<VelovForecastMarker> {
        if (step !in 1..VelovForecast.STEP_COUNT) return emptyList()
        if (stations != this.stations || originEpochMs != this.originEpochMs || filter != this.filter) {
            this.stations = stations
            this.originEpochMs = originEpochMs
            this.filter = filter
            forecastable = stations.filter { it.open && model.knows(it.id) }
            bySteps.clear()
        }
        return bySteps.getOrPut(step) {
            val glances = model.glances(forecastable, originEpochMs, step, filter)
            forecastable.mapIndexed { rank, station ->
                VelovForecastMarker(station, glances[rank].median.roundToInt(), VelovChance.of(glances[rank].probability).level.availability)
            }
        }
    }
}
