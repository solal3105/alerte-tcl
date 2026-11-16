package com.alertetcl.shared

import com.alertetcl.shared.VelovForecastSamples.MONDAY_EVENING
import com.alertetcl.shared.VelovForecastSamples.bundle
import com.alertetcl.shared.VelovForecastSamples.leaf
import com.alertetcl.shared.VelovForecastSamples.logit
import com.alertetcl.shared.VelovForecastSamples.probability
import com.alertetcl.shared.VelovForecastSamples.quantity
import com.alertetcl.shared.VelovForecastSamples.stairs
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecastMarker
import com.alertetcl.shared.models.VelovForecastMarkers
import com.alertetcl.shared.models.VelovForecastModel
import com.alertetcl.shared.models.VelovForecastSite
import com.alertetcl.shared.models.VelovStation
import kotlin.math.roundToInt
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotSame
import kotlin.test.assertSame
import kotlin.test.assertTrue

/** Les marqueurs de la carte quand le curseur d'heure a quitté « Maintenant ». */
class VelovForecastMarkersTest {
    private fun station(id: Int, electric: Int = 2, mechanical: Int = 6, stands: Int = 7, open: Boolean = true) = VelovStation(
        id = id, name = "$id - STATION $id", lat = 45.76, lng = 4.83,
        bikes = electric + mechanical, ebikes = electric, mbikes = mechanical, stands = stands, capacity = 20, open = open
    )

    private val stations = listOf(station(1), station(2, electric = 0, mechanical = 1, stands = 14), station(3, open = false), station(99))

    /**
     * Médianes : 1,4 vélo de plus, 0,6 électrique de moins, 2,5 classiques de plus. Chances : 80 % pour
     * un vélo, 50 % pour un électrique, 20 % pour un classique, 95 % pour une place pendant 12 h puis 10 %.
     */
    private val model = VelovForecastModel(
        bundle(
            variables = listOf("horizon_h"),
            forests = mapOf(
                "velos_q50" to quantity(leaf(1.4)), "elec_q50" to quantity(leaf(-0.6)), "meca_q50" to quantity(leaf(2.5)),
                "velos_p1" to probability(leaf(logit(0.80))), "elec_p1" to probability(leaf(logit(0.50))), "meca_p1" to probability(leaf(logit(0.20))),
                "bornes_p1" to probability(stairs(listOf(12.1), listOf(0.95, 0.10).map(::logit)))
            ),
            stations = listOf(1, 2, 3).map { VelovForecastSite(id = it) }
        )
    )

    private fun markers(filter: VelovFilter, step: Int = 4) = VelovForecastMarkers(model).at(stations, MONDAY_EVENING, step, filter)

    @Test
    fun aMarkerShowsTheMostLikelyCountOfWhatTheFilterCounts() {
        assertEquals(listOf(9, 2), markers(VelovFilter.ALL).map { it.count }, "8 + 1,4 et 1 + 1,4")
        assertEquals(listOf(9, 4), markers(VelovFilter.MECHANICAL).map { it.count }, "6 + 2,5 et 1 + 2,5, arrondis")
        assertEquals(listOf(1, 0), markers(VelovFilter.ELECTRIC).map { it.count }, "2 − 0,6 ; jamais moins de zéro")
        assertEquals(listOf(6, 13), markers(VelovFilter.STANDS).map { it.count }, "les places que laissent les vélos prévus : 7 + 8 − 9,4 et 14 + 1 − 2,4")
    }

    @Test
    fun aMarkerTakesTheColourOfTheChanceForEveryFilter() {
        assertTrue(markers(VelovFilter.ALL).all { it.availability == AvailabilityColor.GREEN }, "80 %")
        assertTrue(markers(VelovFilter.ELECTRIC).all { it.availability == AvailabilityColor.ORANGE }, "50 %")
        assertTrue(markers(VelovFilter.MECHANICAL).all { it.availability == AvailabilityColor.RED }, "20 %, même avec 9 classiques prévus")
        assertTrue(markers(VelovFilter.STANDS, step = 48).all { it.availability == AvailabilityColor.GREEN }, "95 %")
        assertTrue(markers(VelovFilter.STANDS, step = 49).all { it.availability == AvailabilityColor.RED }, "10 %")
    }

    @Test
    fun aStationWithoutForecastHasNoMarker() {
        assertEquals(listOf(1, 2), markers(VelovFilter.ALL).map { it.station.id }, "ni la station fermée, ni celle que le modèle ne connaît pas")
        assertEquals(stations[0], markers(VelovFilter.ALL).first().station)
    }

    @Test
    fun stepZeroIsNotAForecast() {
        assertTrue(markers(VelovFilter.ALL, step = 0).isEmpty())
        assertTrue(markers(VelovFilter.ALL, step = 97).isEmpty())
        assertEquals(2, markers(VelovFilter.ALL, step = 96).size)
    }

    @Test
    fun aMarkerCountsWhatTheModelGivesForThatStepAlone() {
        val glances = model.glances(stations.take(2), MONDAY_EVENING, 30, VelovFilter.STANDS)
        assertEquals(glances.map { it.median.roundToInt() }, markers(VelovFilter.STANDS, step = 30).map { it.count })
    }

    @Test
    fun aStepAlreadyComputedComesBackAtOnce() {
        val memo = VelovForecastMarkers(model)
        val first = memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL)
        val other = memo.at(stations, MONDAY_EVENING, 13, VelovFilter.ALL)
        assertNotSame(first, other)
        assertSame(first, memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL), "aller et retour du curseur")
        assertSame(other, memo.at(stations, MONDAY_EVENING, 13, VelovFilter.ALL))
        assertSame(first, memo.at(stations.toList(), MONDAY_EVENING, 12, VelovFilter.ALL), "même relevé relu dans une autre liste")
    }

    @Test
    fun aNewReadingOfTheStationsForgetsEverything() {
        val memo = VelovForecastMarkers(model)
        val before = memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL)
        val refreshed = listOf(station(1, electric = 0, mechanical = 3)) + stations.drop(1)
        val after = memo.at(refreshed, MONDAY_EVENING, 12, VelovFilter.ALL)
        assertEquals(listOf(9, 2), before.map { it.count })
        assertEquals(listOf(4, 2), after.map { it.count }, "le nouvel état de la station est pris en compte")
        assertEquals(refreshed[0], after.first().station)
        assertNotSame(before, memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL), "l'ancien relevé n'est plus gardé")
    }

    @Test
    fun anotherOriginOrAnotherFilterForgetsEverythingToo() {
        val memo = VelovForecastMarkers(model)
        val first = memo.at(stations, MONDAY_EVENING, 48, VelovFilter.STANDS)
        val later = memo.at(stations, MONDAY_EVENING + 900_000L, 48, VelovFilter.STANDS)
        assertEquals(first, later)
        assertNotSame(first, later)
        assertNotSame(later, memo.at(stations, MONDAY_EVENING, 48, VelovFilter.STANDS), "retour à la première heure : recalculé")

        val bikes = memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ALL)
        assertEquals(listOf(9, 2), bikes.map(VelovForecastMarker::count))
        assertSame(bikes, memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ALL))
        memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ELECTRIC)
        assertNotSame(bikes, memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ALL), "un seul filtre gardé à la fois")
    }
}
