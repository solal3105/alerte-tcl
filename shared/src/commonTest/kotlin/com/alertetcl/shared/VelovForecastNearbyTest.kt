package com.alertetcl.shared

import com.alertetcl.shared.VelovForecastSamples.MONDAY_EVENING
import com.alertetcl.shared.VelovForecastSamples.bundle
import com.alertetcl.shared.VelovForecastSamples.leaf
import com.alertetcl.shared.VelovForecastSamples.logit
import com.alertetcl.shared.VelovForecastSamples.probability
import com.alertetcl.shared.VelovForecastSamples.quantity
import com.alertetcl.shared.VelovForecastSamples.stairs
import com.alertetcl.shared.models.VelovChance
import com.alertetcl.shared.models.VelovChanceLevel
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecastBundle
import com.alertetcl.shared.models.VelovForecastModel
import com.alertetcl.shared.models.VelovForecastNearby
import com.alertetcl.shared.models.VelovForecastSheet
import com.alertetcl.shared.models.VelovForecastSite
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.network.HttpClientProvider
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * « Plus sûr à côté » et l'assemblage de la fiche, avec un vrai modèle écrit à la main : la chance de
 * trouver un vélo n'y dépend que de la latitude de la station, les électriques que de l'échéance.
 */
class VelovForecastNearbyTest {
    private val latitude = 45.7600

    /** Une station à [meters] au nord de la station de la fiche (un degré de latitude fait 111 320 m). */
    private fun station(id: Int, meters: Double, open: Boolean = true) = VelovStation(
        id = id, name = "$id - STATION $id", lat = latitude + meters / 111_320.0, lng = 4.8300,
        bikes = 4, ebikes = 1, mbikes = 3, stands = 6, capacity = 12, open = open
    )

    private val here = station(1, 0.0)
    private val uncertain = station(2, 100.0)   // 55 %
    private val likely = station(3, 220.0)      // 77 %
    private val closed = station(4, 280.0, open = false) // 97 %, mais fermée
    private val nearCertain = station(5, 340.0) // 95 %
    private val unknown = station(6, 400.0)     // absente du modèle
    private val alsoLikely = station(7, 560.0)  // 80 %
    private val tooFar = station(8, 610.0)      // 99 %, mais à plus de 600 m
    private val all = listOf(tooFar, alsoLikely, unknown, nearCertain, closed, likely, uncertain, here)

    /** Seuils de latitude à mi-chemin entre deux stations, et la chance de trouver un vélo de chaque côté. */
    private val model = VelovForecastModel(
        bundle(
            variables = listOf("lat", "horizon_h"),
            decileShifts = listOf(-4.0, -2.0, 0.0, 2.0, 5.0),
            forests = mapOf(
                "velos_p1" to probability(
                    stairs(
                        thresholds = listOf(50.0, 160.0, 250.0, 310.0, 450.0, 585.0).map { latitude + it / 111_320.0 },
                        values = listOf(0.29, 0.55, 0.77, 0.97, 0.95, 0.80, 0.99).map(::logit)
                    )
                ),
                // Les électriques : probables pendant 12 h, puis introuvables partout.
                "elec_p1" to probability(stairs(listOf(12.1), listOf(0.85, 0.05).map(::logit), feature = 1)),
                "elec_q10" to quantity(leaf(-1.0)), "elec_q30" to quantity(leaf(-1.0)), "elec_q50" to quantity(leaf(0.0)),
                "elec_q70" to quantity(leaf(1.0)), "elec_q90" to quantity(leaf(2.0))
            ),
            stations = all.filter { it != unknown }.map { VelovForecastSite(id = it.id, lat = it.lat, lon = it.lng) }
        )
    )

    private fun nearby() = VelovForecastNearby(model, here, all, MONDAY_EVENING)

    @Test
    fun theTwoNearestSafeStationsAreSuggestedNearestFirst() {
        val safer = nearby().saferAt(57, VelovFilter.ALL)
        assertEquals(listOf(likely, nearCertain), safer.map { it.station }, "ni l'incertaine, ni la fermée, ni l'inconnue, ni la troisième")
        assertEquals(listOf(VelovChance(77, VelovChanceLevel.LIKELY), VelovChance(95, VelovChanceLevel.NEAR_CERTAIN)), safer.map { it.chance })
        assertEquals(listOf("4 min à pied · 0 à 9 vélos", "6 min à pied · 0 à 9 vélos"), safer.map { it.detail })
    }

    @Test
    fun neighboursAreJudgedOnWhatTheFilterCounts() {
        assertEquals(listOf("2 min à pied · 0 à 3 électriques", "4 min à pied · 0 à 3 électriques"), nearby().saferAt(48, VelovFilter.ELECTRIC).map { it.detail })
        assertEquals(listOf(uncertain, likely), nearby().saferAt(48, VelovFilter.ELECTRIC).map { it.station })
        assertTrue(nearby().saferAt(49, VelovFilter.ELECTRIC).isEmpty(), "plus aucune voisine n'est sûre")
        assertTrue(nearby().saferAt(57, VelovFilter.STANDS).isEmpty(), "une place sur deux partout : rien de plus sûr")
    }

    @Test
    fun aStationFartherThan600MetresIsNeverSuggested() {
        val alone = VelovForecastNearby(model, here, listOf(here, tooFar), MONDAY_EVENING)
        assertTrue(alone.saferAt(57, VelovFilter.ALL).isEmpty())
        assertEquals(listOf(alsoLikely), VelovForecastNearby(model, here, listOf(here, tooFar, alsoLikely), MONDAY_EVENING).saferAt(57, VelovFilter.ALL).map { it.station })
        assertEquals(600.0, VelovForecastNearby.RADIUS_METERS)
        assertEquals(2, VelovForecastNearby.MAX_SHOWN)
    }

    @Test
    fun aStationTheModelDoesNotKnowIsNeverSuggested() {
        // Un vélo quasi sûr partout : seule l'absence du modèle écarte la station la plus proche.
        val sure = VelovForecastModel(
            bundle(
                forests = mapOf("velos_p1" to probability(leaf(logit(0.95)))),
                stations = listOf(here, alsoLikely).map { VelovForecastSite(id = it.id) }
            )
        )
        val safer = VelovForecastNearby(sure, here, listOf(here, unknown, alsoLikely), MONDAY_EVENING).saferAt(57, VelovFilter.ALL)
        assertEquals(listOf(alsoLikely), safer.map { it.station })
    }

    @Test
    fun walkingTimeCountsTheDetourAndAtLeastOneMinute() {
        assertEquals("1 min à pied", VelovForecastNearby.walk(20.0))
        assertEquals("1 min à pied", VelovForecastNearby.walk(90.0))
        assertEquals("2 min à pied", VelovForecastNearby.walk(100.0))
        assertEquals("6 min à pied", VelovForecastNearby.walk(370.0))
        assertEquals("10 min à pied", VelovForecastNearby.walk(599.0))
    }

    @Test
    fun anAnswerAlreadyGivenIsKept() {
        val nearby = nearby()
        assertSame(nearby.saferAt(57, VelovFilter.ALL), nearby.saferAt(57, VelovFilter.ALL))
        assertEquals(nearby.saferAt(57, VelovFilter.ALL), nearby.saferAt(58, VelovFilter.ALL))
    }

    // --- La fiche assemblée à partir du modèle ([VelovForecastSheet.of]).

    @Test
    fun theSheetOfAStationCarriesItsForecastAndItsNeighbours() {
        val sheet = assertNotNull(VelovForecastSheet.of(model, here, all, MONDAY_EVENING))
        val morning = sheet.readout(VelovFilter.ALL, 57)
        assertEquals("Demain · 9 h", morning.time)
        assertEquals("0 à 9 vélos", morning.count)
        assertEquals(VelovChance(29, VelovChanceLevel.UNLIKELY), morning.chance)
        assertNull(morning.reliability, "ce modèle n'a pas de contrôle")
        assertEquals(listOf(likely, nearCertain), morning.saferNearby.map { it.station })
        assertEquals("Souvent vide à partir de 19 h", sheet.panel(VelovFilter.ALL).risk)

        val electric = sheet.readout(VelovFilter.ELECTRIC, 48)
        assertEquals("0 à 3 électriques", electric.count)
        assertEquals(VelovChance(85, VelovChanceLevel.LIKELY), electric.chance)
        assertTrue(electric.saferNearby.isEmpty())
        assertEquals("Souvent sans électrique demain à partir de 7 h", sheet.panel(VelovFilter.ELECTRIC).risk)
        assertEquals("1 à 10 places", sheet.readout(VelovFilter.STANDS, 4).count, "6 places et 4 vélos, dont il restera de 0 à 9")
    }

    @Test
    fun theSheetReadsTheReliabilityMeasuredByTheRobot() {
        val fixture = VelovForecastModel(
            HttpClientProvider.json.decodeFromString(VelovForecastBundle.serializer(), VelovForecastFixture.BUNDLE)
        )
        val station = station(1001, 0.0)
        val sheet = assertNotNull(VelovForecastSheet.of(fixture, station, listOf(station), MONDAY_EVENING))
        assertEquals("8 fois sur 10", sheet.readout(VelovFilter.ALL, 4).reliability)
        assertEquals("7 fois sur 10", sheet.readout(VelovFilter.MECHANICAL, 4).reliability)
        assertEquals("9 fois sur 10", sheet.readout(VelovFilter.ELECTRIC, 4).reliability)
        assertNull(sheet.readout(VelovFilter.STANDS, 4).reliability, "couverture des places absente du fichier")
    }

    @Test
    fun aClosedOrUnknownStationHasNoForecast() {
        assertNull(VelovForecastSheet.of(model, closed, all, MONDAY_EVENING))
        assertNull(VelovForecastSheet.of(model, unknown, all, MONDAY_EVENING))
        assertNotNull(VelovForecastSheet.of(model, likely, all, MONDAY_EVENING))
    }
}
