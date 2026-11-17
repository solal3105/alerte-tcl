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
import com.alertetcl.shared.models.VelovForecastMarkers
import com.alertetcl.shared.models.VelovForecastModel
import com.alertetcl.shared.models.VelovForecastSheet
import com.alertetcl.shared.models.VelovForecastSite
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.models.VelovTexts
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNotSame
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/** Les marqueurs de la carte quand le curseur d'heure a quitté « Maintenant », et leur calcul d'avance. */
@OptIn(ExperimentalCoroutinesApi::class)
class VelovForecastMarkersTest {
    private fun station(id: Int, electric: Int = 2, mechanical: Int = 6, stands: Int = 7, open: Boolean = true) = VelovStation(
        id = id, name = "$id - STATION $id", lat = 45.76, lng = 4.83,
        bikes = electric + mechanical, ebikes = electric, mbikes = mechanical, stands = stands, capacity = 20, open = open
    )

    private val stations = listOf(station(1), station(2, electric = 0, mechanical = 1, stands = 14), station(3, open = false), station(99))

    /**
     * Écarts au nombre présent, pour les trois sortes : −3, −1, 0, +1 et +2,4 (déciles 10 à 90). Chances :
     * 80 % pour un vélo, 50 % pour un électrique, 20 % pour un classique, 95 % pour une place pendant
     * 12 h puis 10 %.
     */
    private val model = VelovForecastModel(
        bundle(
            variables = listOf("horizon_h"),
            decileShifts = listOf(-3.0, -1.0, 0.0, 1.0, 2.4),
            forests = mapOf(
                "velos_p1" to probability(leaf(logit(0.80))), "elec_p1" to probability(leaf(logit(0.50))), "meca_p1" to probability(leaf(logit(0.20))),
                "bornes_p1" to probability(stairs(listOf(12.1), listOf(0.95, 0.10).map(::logit)))
            ),
            stations = listOf(1, 2, 3).map { VelovForecastSite(id = it) }
        )
    )

    /** Le calcul d'arrière-plan tourne dans le test lui-même, pour que `advanceUntilIdle` le mène à son terme. */
    private fun TestScope.memo(model: VelovForecastModel = this@VelovForecastMarkersTest.model) =
        VelovForecastMarkers(model, this, StandardTestDispatcher(testScheduler))

    private suspend fun VelovForecastMarkers.labels(filter: VelovFilter, step: Int = 4, stations: List<VelovStation> = this@VelovForecastMarkersTest.stations) =
        at(stations, MONDAY_EVENING, step, filter)?.map { it.label }

    @Test
    fun aMarkerShowsTheRangeOfWhatTheFilterCounts() = runTest {
        val memo = memo()
        assertEquals(listOf("5–10", "0–3"), memo.labels(VelovFilter.ALL), "8 vélos − 3 à + 2,4 ; 1 vélo, jamais moins de zéro")
        assertEquals(listOf("3–8", "0–3"), memo.labels(VelovFilter.MECHANICAL))
        assertEquals(listOf("0–4", "0–2"), memo.labels(VelovFilter.ELECTRIC))
        assertEquals(listOf("5–10", "12–15"), memo.labels(VelovFilter.STANDS), "les places que laissent les vélos prévus : 7 + 8 − 10,4 à 7 + 8 − 5")
    }

    @Test
    fun aRangeIsWrittenShortWithoutUnit() {
        assertEquals("3–8", VelovTexts.shortRange(3..8))
        assertEquals("5", VelovTexts.shortRange(5..5), "deux bornes égales font un seul nombre")
        assertEquals("0–1", VelovTexts.shortRange(0..1))
    }

    @Test
    fun aMarkerTakesTheColourOfTheChanceForEveryFilter() = runTest {
        val memo = memo()
        suspend fun colours(filter: VelovFilter, step: Int = 4) = memo.at(stations, MONDAY_EVENING, step, filter)!!.map { it.availability }.toSet()
        assertEquals(setOf(AvailabilityColor.GREEN), colours(VelovFilter.ALL), "80 %")
        assertEquals(setOf(AvailabilityColor.ORANGE), colours(VelovFilter.ELECTRIC), "50 %")
        assertEquals(setOf(AvailabilityColor.RED), colours(VelovFilter.MECHANICAL), "20 %, même avec 3 à 8 classiques prévus")
        assertEquals(setOf(AvailabilityColor.GREEN), colours(VelovFilter.STANDS, step = 48), "95 %")
        assertEquals(setOf(AvailabilityColor.RED), colours(VelovFilter.STANDS, step = 49), "10 %")
    }

    /**
     * Le marqueur et la fiche écrivent toujours la même fourchette, même quand les déciles se croisent
     * (le décile 10 passe ici au-dessus des autres au-delà de 6 h, et le 90 sous la médiane après 18 h).
     */
    @Test
    fun theMarkerAndTheSheetAlwaysAgreeOnTheBounds() = runTest {
        val crossing = VelovForecastModel(
            bundle(
                variables = listOf("horizon_h"),
                decileShifts = listOf(-2.6, -0.4, 0.5, 1.4, 3.6),
                forests = mapOf(
                    "velos_q10" to quantity(stairs(listOf(6.1), listOf(-2.6, 1.7))),
                    "elec_q10" to quantity(stairs(listOf(6.1), listOf(-1.4, 0.6))),
                    "meca_q90" to quantity(stairs(listOf(18.1), listOf(3.6, 0.2))),
                    "velos_q90" to quantity(stairs(listOf(18.1), listOf(3.6, -0.6)))
                ),
                stations = listOf(1, 2, 3).map { VelovForecastSite(id = it) }
            )
        )
        val memo = memo(crossing)
        val forecastable = stations.take(2)
        val sheets = forecastable.map { VelovForecastSheet.of(crossing, it, stations, MONDAY_EVENING)!! }
        fun bounds(text: String) = Regex("\\d+").findAll(text).map { it.value.toInt() }.toList().let { listOf(it.first(), it.last()) }
        for (filter in VelovFilter.ordered) for (step in 1..96) {
            val markers = memo.at(stations, MONDAY_EVENING, step, filter)!!
            forecastable.indices.forEach { rank ->
                assertEquals(bounds(sheets[rank].readout(filter, step).count), bounds(markers[rank].label), "${forecastable[rank].id}, $filter, échéance $step")
            }
        }
    }

    @Test
    fun aStationWithoutForecastHasNoMarker() = runTest {
        val markers = memo().at(stations, MONDAY_EVENING, 4, VelovFilter.ALL)!!
        assertEquals(listOf(1, 2), markers.map { it.station.id }, "ni la station fermée, ni celle que le modèle ne connaît pas")
        assertEquals(stations[0], markers.first().station)
    }

    @Test
    fun stepZeroIsNotAForecast() = runTest {
        val memo = memo()
        assertEquals(emptyList(), memo.labels(VelovFilter.ALL, step = 0))
        assertEquals(emptyList(), memo.labels(VelovFilter.ALL, step = 97))
        assertEquals(2, memo.labels(VelovFilter.ALL, step = 96)?.size)
    }

    @Test
    fun theStepsAreComputedFromTheLastOneAsked() {
        assertEquals(60, VelovForecastMarkers.nextStep(60, emptySet()))
        assertEquals(61, VelovForecastMarkers.nextStep(60, setOf(60)), "à égale distance, la suivante d'abord")
        assertEquals(59, VelovForecastMarkers.nextStep(60, setOf(60, 61)))
        assertEquals(62, VelovForecastMarkers.nextStep(60, setOf(59, 60, 61)))
        assertEquals(1, VelovForecastMarkers.nextStep(96, (2..96).toSet()))
        assertNull(VelovForecastMarkers.nextStep(5, (1..96).toSet()), "tout est prêt")
    }

    @Test
    fun preparingComputesEveryStepInTheBackground() = runTest {
        val memo = memo()
        memo.prepare(stations, MONDAY_EVENING, VelovFilter.ALL)
        advanceUntilIdle()
        assertEquals((1..96).toSet(), memo.readySteps())
        val first = memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL)
        assertSame(first, memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL), "une échéance prête revient telle quelle")
        assertSame(first, memo.at(stations.toList(), MONDAY_EVENING, 12, VelovFilter.ALL), "même relevé relu dans une autre liste")
    }

    @Test
    fun preparingAgainWithTheSameArgumentsKeepsEverything() = runTest {
        val memo = memo()
        memo.prepare(stations, MONDAY_EVENING, VelovFilter.ELECTRIC)
        advanceUntilIdle()
        val before = memo.at(stations, MONDAY_EVENING, 30, VelovFilter.ELECTRIC)
        memo.prepare(stations.toList(), MONDAY_EVENING, VelovFilter.ELECTRIC)
        advanceUntilIdle()
        assertSame(before, memo.at(stations, MONDAY_EVENING, 30, VelovFilter.ELECTRIC))
    }

    @Test
    fun anAskedStepIsComputedBeforeTheOthers() = runTest {
        val memo = memo()
        memo.prepare(stations, MONDAY_EVENING, VelovFilter.ALL)
        assertNotNull(memo.at(stations, MONDAY_EVENING, 80, VelovFilter.ALL))
        assertTrue(memo.readySteps().size < 96, "l'échéance 80 est arrivée bien avant la fin du calcul")
        advanceUntilIdle()
        assertEquals(96, memo.readySteps().size)
    }

    @Test
    fun aRequestOvertakenByAnotherAnswersNull() = runTest {
        val memo = memo()
        val overtaken = async { memo.at(stations, MONDAY_EVENING, 10, VelovFilter.ALL) }
        val latest = async { memo.at(stations, MONDAY_EVENING, 11, VelovFilter.ALL) }
        advanceUntilIdle()
        assertNull(overtaken.await(), "le curseur a continué de glisser")
        assertEquals(listOf("5–10", "0–3"), latest.await()?.map { it.label })
    }

    @Test
    fun aNewReadingOfTheStationsStartsAgain() = runTest {
        val memo = memo()
        memo.prepare(stations, MONDAY_EVENING, VelovFilter.ALL)
        advanceUntilIdle()
        val before = memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL)
        val refreshed = listOf(station(1, electric = 0, mechanical = 3)) + stations.drop(1)
        memo.prepare(refreshed, MONDAY_EVENING, VelovFilter.ALL)
        advanceUntilIdle()
        assertEquals(96, memo.readySteps().size)
        val after = memo.at(refreshed, MONDAY_EVENING, 12, VelovFilter.ALL)
        assertEquals(listOf("5–10", "0–3"), before?.map { it.label })
        assertEquals(listOf("0–5", "0–3"), after?.map { it.label }, "le nouvel état de la station est pris en compte")
        assertEquals(refreshed[0], after?.first()?.station)
        assertNotSame(before, memo.at(stations, MONDAY_EVENING, 12, VelovFilter.ALL), "l'ancien relevé n'est plus gardé")
    }

    @Test
    fun anotherOriginOrAnotherFilterStartsAgainToo() = runTest {
        val memo = memo()
        val first = memo.at(stations, MONDAY_EVENING, 48, VelovFilter.STANDS)
        val later = memo.at(stations, MONDAY_EVENING + 900_000L, 48, VelovFilter.STANDS)
        assertEquals(first, later)
        assertNotSame(first, later)
        assertNotSame(later, memo.at(stations, MONDAY_EVENING, 48, VelovFilter.STANDS), "retour à la première heure : recalculé")

        val bikes = memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ALL)
        assertSame(bikes, memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ALL))
        memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ELECTRIC)
        assertNotSame(bikes, memo.at(stations, MONDAY_EVENING, 48, VelovFilter.ALL), "un seul filtre gardé à la fois")
    }
}
