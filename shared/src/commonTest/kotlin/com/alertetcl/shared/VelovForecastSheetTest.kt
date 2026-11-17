package com.alertetcl.shared

import com.alertetcl.shared.VelovForecastSamples.MONDAY_EVENING
import com.alertetcl.shared.models.VelovChance
import com.alertetcl.shared.models.VelovChanceLevel
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecast
import com.alertetcl.shared.models.VelovForecastNeighbour
import com.alertetcl.shared.models.VelovForecastOutlook
import com.alertetcl.shared.models.VelovForecastSheet
import com.alertetcl.shared.models.VelovForecastState
import com.alertetcl.shared.models.VelovForecastStep
import com.alertetcl.shared.models.VelovStation
import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Ce que la fiche d'une station écrit et dessine, à partir de prévisions posées à la main. */
class VelovForecastSheetTest {
    private val levels = listOf(10, 30, 50, 70, 90)

    /** Place Sathonay dans la maquette : 5 classiques, 9 électriques, 4 places, 22 bornes. */
    private val state = VelovForecastState(electric = 9, mechanical = 5, docks = 4, capacity = 22)

    private fun outlook(low: Double, high: Double, probability: Double): VelovForecastOutlook {
        val middle = (low + high) / 2
        return VelovForecastOutlook(levels, listOf(low, (low + middle) / 2, middle, (middle + high) / 2, high), probability)
    }

    private val steady = outlook(6.6, 17.4, 0.997)

    /** 96 échéances : [counted] donne ce que compte [filter] à chacune (numérotée à partir de 1), le reste ne bouge pas. */
    private fun forecast(filter: VelovFilter = VelovFilter.ALL, state: VelovForecastState = this.state, counted: (Int) -> VelovForecastOutlook) =
        VelovForecast(state, (1..96).map { step ->
            fun at(other: VelovFilter) = if (other == filter) counted(step) else steady
            VelovForecastStep(at(VelovFilter.ALL), at(VelovFilter.MECHANICAL), at(VelovFilter.ELECTRIC), at(VelovFilter.STANDS))
        })

    private val coverage = mapOf(VelovFilter.ALL to 0.8276, VelovFilter.ELECTRIC to 0.9049, VelovFilter.STANDS to 0.7461)

    private fun sheet(
        forecast: VelovForecast = forecast { steady },
        origin: Long = MONDAY_EVENING,
        nearby: (Int, VelovFilter) -> List<VelovForecastNeighbour> = { _, _ -> error("aucune voisine à chercher") }
    ) = VelovForecastSheet(forecast, origin, coverage, nearby)

    /** Une prévision dont la chance de [filter] vaut [low] de l'échéance [from] à [to], et [high] ailleurs. */
    private fun dipping(from: Int, to: Int, filter: VelovFilter = VelovFilter.ALL, low: Double = 0.29, high: Double = 0.8) =
        forecast(filter) { step -> outlook(0.0, 2.0, if (step in from..to) low else high) }

    // --- L'échéance 0 : l'état réel.

    @Test
    fun atStepZeroTheSheetOnlyStatesWhatIsThere() {
        val now = sheet().readout(VelovFilter.ALL, 0)
        assertEquals(0, now.step)
        assertEquals("Maintenant", now.time)
        assertEquals("14 vélos", now.count)
        assertNull(now.reliability)
        assertNull(now.chance)
        assertTrue(now.saferNearby.isEmpty())
        assertEquals(listOf("14 vélos", "5 classiques", "9 électriques", "4 places"), VelovFilter.ordered.map { sheet().readout(it, 0).count })
    }

    @Test
    fun theCountNowIsSingularUpToOne() {
        val almostEmpty = sheet(forecast(state = VelovForecastState(electric = 1, mechanical = 0, docks = 1, capacity = 20)) { steady })
        assertEquals(listOf("1 vélo", "0 classique", "1 électrique", "1 place"), VelovFilter.ordered.map { almostEmpty.readout(it, 0).count })
    }

    // --- Une échéance prévue.

    @Test
    fun aForecastStepGivesTheRangeItsReliabilityAndTheChance() {
        val soon = sheet().readout(VelovFilter.ALL, 2)
        assertEquals(2, soon.step)
        assertEquals("Dans 30 min · 19 h 15", soon.time)
        assertEquals("7 à 17 vélos", soon.count)
        assertEquals("8 fois sur 10", soon.reliability)
        assertEquals(VelovChance(99, VelovChanceLevel.NEAR_CERTAIN), soon.chance)
        assertEquals("99 %", soon.chance?.text)
        assertEquals("quasi sûr", soon.chance?.level?.label)
        assertTrue(soon.saferNearby.isEmpty())
    }

    @Test
    fun eachFilterHasItsOwnRangeChanceAndReliability() {
        fun readout(filter: VelovFilter) = sheet(forecast(filter) { outlook(0.2, 8.7, 0.82) }).readout(filter, 4)
        assertEquals("0 à 9 places", readout(VelovFilter.STANDS).count)
        assertEquals("7 fois sur 10", readout(VelovFilter.STANDS).reliability)
        assertEquals(VelovChance(82, VelovChanceLevel.LIKELY), readout(VelovFilter.STANDS).chance)
        assertEquals("0 à 9 électriques", readout(VelovFilter.ELECTRIC).count)
        assertEquals("9 fois sur 10", readout(VelovFilter.ELECTRIC).reliability)
        assertEquals("0 à 9 classiques", readout(VelovFilter.MECHANICAL).count)
        assertNull(readout(VelovFilter.MECHANICAL).reliability, "fourchette que le robot n'a pas mesurée : pas de chiffre")
        // Les autres filtres de la même fiche gardent leur propre prévision.
        assertEquals("7 à 17 vélos", sheet(forecast(VelovFilter.STANDS) { outlook(0.2, 8.7, 0.82) }).readout(VelovFilter.ALL, 4).count)
    }

    @Test
    fun aRangeReducedToOneNumberIsWrittenOnce() {
        assertEquals("12 vélos", sheet(forecast { outlook(11.6, 12.4, 0.99) }).readout(VelovFilter.ALL, 1).count)
        assertEquals("0 à 1 vélo", sheet(forecast { outlook(0.0, 1.2, 0.5) }) { _, _ -> emptyList() }.readout(VelovFilter.ALL, 1).count)
    }

    @Test
    fun theWrittenRangeIsNotTheSmoothedOneOfTheChart() {
        val jagged = sheet(forecast { step -> if (step == 2) outlook(10.0, 20.0, 0.99) else outlook(4.0, 8.0, 0.99) })
        assertEquals("10 à 20 vélos", jagged.readout(VelovFilter.ALL, 2).count)
        assertEquals(12.0, jagged.panel(VelovFilter.ALL).points[2].high, 1e-12)
    }

    // --- L'heure de l'échéance.

    @Test
    fun aStepIsAnnouncedByItsDelayThenByItsDay() {
        val sheet = sheet()
        assertEquals("Dans 15 min · 19 h", sheet.readout(VelovFilter.ALL, 1).time)
        assertEquals("Dans 1 h · 19 h 45", sheet.readout(VelovFilter.ALL, 4).time)
        assertEquals("Dans 5 h · 23 h 45", sheet.readout(VelovFilter.ALL, 20).time)
        assertEquals("Demain · 0 h", sheet.readout(VelovFilter.ALL, 21).time)
        assertEquals("Demain · 8 h 30", sheet.readout(VelovFilter.ALL, 55).time)
        assertEquals("Demain · 9 h", sheet.readout(VelovFilter.ALL, 57).time)
        assertEquals("Demain · 18 h 45", sheet.readout(VelovFilter.ALL, 96).time)
    }

    @Test
    fun withinTwoHoursAStepPastMidnightKeepsItsDelay() {
        // 23 h 30 : minuit est dans une demi-heure, pas « demain ».
        val late = sheet(origin = Instant.parse("2026-11-16T22:30:00Z").toEpochMilliseconds())
        assertEquals("Dans 15 min · 23 h 45", late.readout(VelovFilter.ALL, 1).time)
        assertEquals("Dans 30 min · 0 h", late.readout(VelovFilter.ALL, 2).time)
        assertEquals("Dans 2 h · 1 h 30", late.readout(VelovFilter.ALL, 8).time)
        assertEquals("Demain · 1 h 45", late.readout(VelovFilter.ALL, 9).time)
    }

    @Test
    fun aStepLaterTheSameDayKeepsItsDelay() {
        // 0 h 30 : 14 h 15 est aujourd'hui.
        val early = sheet(origin = Instant.parse("2026-11-16T23:30:00Z").toEpochMilliseconds())
        assertEquals("Dans 13 h 45 · 14 h 15", early.readout(VelovFilter.ALL, 55).time)
        assertEquals("Demain · 0 h 30", early.readout(VelovFilter.ALL, 96).time)
    }

    @Test
    fun theStepIsKeptBetweenNowAndTheLastOne() {
        val sheet = sheet()
        assertEquals(sheet.readout(VelovFilter.ALL, 0), sheet.readout(VelovFilter.ALL, -3))
        assertEquals(sheet.readout(VelovFilter.ALL, 96), sheet.readout(VelovFilter.ALL, 200))
        assertEquals(96, sheet.readout(VelovFilter.ALL, 200).step)
    }

    // --- « Plus sûr à côté ».

    @Test
    fun neighboursAreOnlySoughtWhenTheChanceIsLow() {
        val asked = mutableListOf<Pair<Int, VelovFilter>>()
        val neighbour = VelovForecastNeighbour(
            VelovStation(id = 5001, name = "5001 - SAINT-PAUL", lat = 45.766, lng = 4.827, bikes = 3, stands = 9),
            "6 min à pied · 0 à 9 vélos", VelovChance.of(0.77)
        )
        fun sheet(probability: Double) = sheet(forecast { outlook(0.0, 2.0, probability) }) { step, filter ->
            asked += step to filter
            listOf(neighbour)
        }
        assertTrue(sheet(0.90).readout(VelovFilter.ALL, 57).saferNearby.isEmpty(), "quasi sûr")
        assertTrue(sheet(0.70).readout(VelovFilter.ALL, 57).saferNearby.isEmpty(), "probable")
        assertTrue(asked.isEmpty())
        assertEquals(listOf(neighbour), sheet(0.69).readout(VelovFilter.ALL, 57).saferNearby, "incertain")
        assertEquals(listOf(neighbour), sheet(0.29).readout(VelovFilter.ALL, 12).saferNearby, "peu probable")
        assertEquals(listOf(57 to VelovFilter.ALL, 12 to VelovFilter.ALL), asked)
        assertTrue(sheet(0.29).readout(VelovFilter.ALL, 0).saferNearby.isEmpty(), "maintenant : rien n'est prévu")
        assertEquals("Plus sûr à côté", VelovForecastSheet.SAFER_NEARBY_TITLE)
    }

    @Test
    fun neighboursAreSoughtForTheFilterOfTheSheet() {
        val asked = mutableListOf<Pair<Int, VelovFilter>>()
        val sheet = sheet(dipping(1, 96, VelovFilter.ELECTRIC)) { step, filter -> asked += step to filter; emptyList() }
        sheet.readout(VelovFilter.ELECTRIC, 30)
        sheet.readout(VelovFilter.ALL, 30)
        assertEquals(listOf(30 to VelovFilter.ELECTRIC), asked)
    }

    // --- Le graphique et le curseur.

    @Test
    fun theChartStartsFromTheRealStateThenFollowsTheForecast() {
        val panel = sheet(forecast { step -> VelovForecastOutlook(levels, listOf(1.0, 2.0, 3.0, 4.0, 5.0).map { it * step }, 0.9) }).panel(VelovFilter.ALL)
        assertEquals(97, panel.points.size)
        val first = panel.points.first()
        assertEquals(listOf(0.0, 14.0, 14.0, 14.0, 14.0, 14.0), listOf(first.position, first.median, first.low, first.high, first.midLow, first.midHigh))
        assertEquals((0..96).map { it / 96.0 }, panel.points.map { it.position })
        // Lissage sur trois échéances : la première et la dernière comptent double, le présent n'y entre pas.
        val middle = panel.points[10]
        assertEquals(listOf(30.0, 10.0, 50.0, 20.0, 40.0), listOf(middle.median, middle.low, middle.high, middle.midLow, middle.midHigh))
        assertEquals((3.0 + 3.0 + 6.0) / 3, panel.points[1].median, 1e-12)
        assertEquals((95 * 5.0 + 96 * 5.0 + 96 * 5.0) / 3, panel.points[96].high, 1e-12)
    }

    @Test
    fun theChartOfEachFilterStartsFromItsOwnCount() {
        val sheet = sheet()
        assertEquals(listOf(14.0, 5.0, 9.0, 4.0), VelovFilter.ordered.map { sheet.panel(it).points.first().median })
    }

    @Test
    fun theVerticalScaleIsTheCapacity() {
        assertEquals(listOf(22, 22, 22, 22), VelovFilter.ordered.map { sheet().panel(it).scaleMax })
        assertEquals(1, sheet(forecast(state = VelovForecastState(0, 0, 0, 0)) { steady }).panel(VelovFilter.ALL).scaleMax, "capacité inconnue")
        val overfull = sheet(forecast(state = VelovForecastState(electric = 10, mechanical = 14, docks = 0, capacity = 22)) { steady })
        assertEquals(24, overfull.panel(VelovFilter.ALL).scaleMax, "plus de vélos que de bornes annoncées : le point réel reste dans le cadre")
    }

    @Test
    fun theSliderIsMarkedEverySixHoursAndTheChartAtMidnight() {
        val panel = sheet().panel(VelovFilter.ALL)
        assertEquals(listOf("0 h", "6 h", "12 h", "18 h"), panel.ticks.map { it.label })
        assertEquals(listOf(5.25, 11.25, 17.25, 23.25).map { it / 24 }, panel.ticks.map { it.position })
        assertEquals("mardi", panel.midnight?.label)
        assertEquals(5.25 / 24, panel.midnight?.position)
    }

    @Test
    fun theSliderTrackTakesTheLevelOfEachStep() {
        val probabilities = listOf(0.95, 0.90, 0.75, 0.5, 0.2)
        val panel = sheet(forecast(VelovFilter.STANDS) { step -> outlook(0.0, 5.0, probabilities[(step - 1) / 20]) }).panel(VelovFilter.STANDS)
        assertEquals(96, panel.trackLevels.size)
        assertEquals(
            listOf(VelovChanceLevel.NEAR_CERTAIN, VelovChanceLevel.NEAR_CERTAIN, VelovChanceLevel.LIKELY, VelovChanceLevel.UNCERTAIN, VelovChanceLevel.UNLIKELY),
            listOf(0, 20, 40, 60, 95).map { panel.trackLevels[it] }
        )
        assertTrue(sheet().panel(VelovFilter.ALL).trackLevels.all { it == VelovChanceLevel.NEAR_CERTAIN })
    }

    // --- La période à risque.

    @Test
    fun theRiskSentenceNamesTheFirstUnlikelyPeriod() {
        // De 7 h à 9 h 45 le lendemain, comme sur la maquette.
        assertEquals("Souvent vide demain de 7 h à 9 h 45", sheet(dipping(49, 60)).panel(VelovFilter.ALL).risk)
        assertEquals("Souvent vide de 19 h à 19 h 45", sheet(dipping(1, 4)).panel(VelovFilter.ALL).risk, "aujourd'hui : le jour ne se dit pas")
        assertEquals("Souvent vide de 23 h à 6 h", sheet(dipping(17, 45)).panel(VelovFilter.ALL).risk, "commence aujourd'hui")
        assertEquals("Souvent vide demain de 0 h à 6 h", sheet(dipping(21, 45)).panel(VelovFilter.ALL).risk)
        assertEquals("Souvent vide demain de 17 h à 18 h 30", sheet(dipping(89, 95)).panel(VelovFilter.ALL).risk, "s'arrête avant la dernière échéance")
    }

    @Test
    fun aRiskThatRunsToTheLastStepHasNoEnd() {
        assertEquals("Souvent vide demain à partir de 17 h", sheet(dipping(89, 96)).panel(VelovFilter.ALL).risk)
        assertEquals("Souvent vide à partir de 19 h", sheet(dipping(1, 96)).panel(VelovFilter.ALL).risk, "les 24 heures entières")
        assertEquals("Souvent vide demain à partir de 18 h 45", sheet(dipping(96, 96)).panel(VelovFilter.ALL).risk)
    }

    @Test
    fun aRiskOfOneStepIsGivenAsAnHour() {
        assertEquals("Souvent vide vers 19 h 15", sheet(dipping(2, 2)).panel(VelovFilter.ALL).risk)
        assertEquals("Souvent vide demain vers 9 h", sheet(dipping(57, 57)).panel(VelovFilter.ALL).risk)
    }

    @Test
    fun theRiskSentenceSaysWhatIsMissing() {
        assertEquals("Souvent sans classique demain de 7 h à 9 h 45", sheet(dipping(49, 60, VelovFilter.MECHANICAL)).panel(VelovFilter.MECHANICAL).risk)
        assertEquals("Souvent sans électrique demain de 7 h à 9 h 45", sheet(dipping(49, 60, VelovFilter.ELECTRIC)).panel(VelovFilter.ELECTRIC).risk)
        assertEquals("Souvent pleine demain de 7 h à 9 h 45", sheet(dipping(49, 60, VelovFilter.STANDS)).panel(VelovFilter.STANDS).risk)
        assertNull(sheet(dipping(49, 60, VelovFilter.STANDS)).panel(VelovFilter.ALL).risk, "chaque filtre a sa propre période")
    }

    @Test
    fun onlyTheFirstPeriodIsNamed() {
        val twice = forecast { step -> outlook(0.0, 2.0, if (step in 5..8 || step in 49..60) 0.1 else 0.8) }
        assertEquals("Souvent vide de 20 h à 20 h 45", sheet(twice).panel(VelovFilter.ALL).risk)
    }

    @Test
    fun withoutAnUnlikelyPeriodThereIsNoRiskSentence() {
        assertNull(sheet().panel(VelovFilter.ALL).risk)
        assertNull(sheet(dipping(49, 60, low = 0.40)).panel(VelovFilter.ALL).risk, "incertain n'est pas un risque annoncé")
        assertEquals("Souvent vide demain de 7 h à 9 h 45", sheet(dipping(49, 60, low = 0.39)).panel(VelovFilter.ALL).risk)
    }
}
