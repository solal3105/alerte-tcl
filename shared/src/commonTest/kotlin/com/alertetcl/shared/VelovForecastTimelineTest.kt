package com.alertetcl.shared

import com.alertetcl.shared.models.VelovForecastMapPanel
import com.alertetcl.shared.models.VelovForecastTick
import com.alertetcl.shared.models.VelovForecastTimeline
import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class VelovForecastTimelineTest {
    private fun at(iso: String) = Instant.parse(iso).toEpochMilliseconds()
    private fun timeline(iso: String) = VelovForecastTimeline(at(iso))

    /** Lundi 16 novembre 2026, 18 h 45 à Lyon : le départ des maquettes. */
    private val monday = timeline("2026-11-16T17:45:00Z")

    private fun assertTicks(expected: List<Pair<Double, String>>, actual: List<VelovForecastTick>) {
        assertEquals(expected.map { it.second }, actual.map { it.label })
        expected.forEachIndexed { rank, (hoursAfterOrigin, label) -> assertEquals(hoursAfterOrigin / 24, actual[rank].position, 1e-12, label) }
    }

    @Test
    fun theOriginOfTheSamplesIsTheOneOfTheMockUps() {
        assertEquals(at("2026-11-16T17:45:00Z"), VelovForecastSamples.MONDAY_EVENING)
    }

    @Test
    fun anHourIsWrittenTheFrenchWay() {
        assertEquals("19 h", monday.clock(1))
        assertEquals("19 h 15", monday.clock(2))
        assertEquals("9 h", monday.clock(57))
        assertEquals("0 h", monday.clock(21))
        assertEquals("0 h 15", monday.clock(22))
        assertEquals("19 h 05", timeline("2026-11-16T17:50:00Z").clock(1), "minutes sur deux chiffres")
    }

    @Test
    fun anHourIsRoundedToFiveMinutes() {
        assertEquals("19 h 15", timeline("2026-11-16T17:47:20Z").clock(2), "19 h 17 min 20 s")
        assertEquals("19 h 20", timeline("2026-11-16T17:47:30Z").clock(2), "19 h 17 min 30 s")
        assertEquals("19 h 15", timeline("2026-11-16T17:44:58Z").clock(2), "deux secondes avant le quart d'heure")
        assertEquals("20 h", timeline("2026-11-16T18:28:00Z").clock(2), "l'arrondi passe à l'heure suivante")
    }

    @Test
    fun tomorrowStartsAtMidnightInLyon() {
        assertFalse(monday.isNextDay(0))
        assertFalse(monday.isNextDay(20), "23 h 45")
        assertTrue(monday.isNextDay(21), "minuit")
        assertTrue(monday.isNextDay(96))
        // 23 h 58 : un quart d'heure plus tard, on est demain.
        assertTrue(timeline("2026-11-16T22:58:00Z").isNextDay(1))
        // 0 h 10 : toute la journée d'aujourd'hui reste devant, jusqu'à 23 h 55.
        val earlyMorning = timeline("2026-11-16T23:10:00Z")
        assertFalse(earlyMorning.isNextDay(95))
        assertTrue(earlyMorning.isNextDay(96))
        // 23 h 43 : l'heure affichée, arrondie à 0 h, est déjà demain.
        assertEquals("0 h", timeline("2026-11-16T22:43:00Z").clock(1))
        assertTrue(timeline("2026-11-16T22:43:00Z").isNextDay(1))
    }

    @Test
    fun delaysCountQuartersOfAnHour() {
        assertEquals(listOf("15 min", "30 min", "45 min", "1 h", "1 h 15", "2 h", "13 h 45", "24 h"), listOf(1, 2, 3, 4, 5, 8, 55, 96).map(VelovForecastTimeline::delay))
    }

    @Test
    fun ticksFallOnRoundHoursAtTheirExactPlace() {
        assertTicks(listOf(5.25 to "0 h", 11.25 to "6 h", 17.25 to "12 h", 23.25 to "18 h"), monday.ticks(6))
        assertTicks(
            listOf(2.25 to "21 h", 5.25 to "0 h", 8.25 to "3 h", 11.25 to "6 h", 14.25 to "9 h", 17.25 to "12 h", 20.25 to "15 h", 23.25 to "18 h"),
            monday.ticks(3)
        )
        // Départ qui ne tombe pas sur un quart d'heure : les repères restent sur les heures rondes.
        assertTicks(listOf(5.2 to "0 h", 11.2 to "6 h", 17.2 to "12 h", 23.2 to "18 h"), timeline("2026-11-16T17:48:00Z").ticks(6))
    }

    @Test
    fun aRoundHourAtTheOriginIsOnlyWrittenAtTheEnd() {
        assertTicks(listOf(6.0 to "0 h", 12.0 to "6 h", 18.0 to "12 h", 24.0 to "18 h"), timeline("2026-11-16T17:00:00Z").ticks(6))
    }

    @Test
    fun midnightCarriesTheNameOfTheDayThatStarts() {
        val midnight = monday.midnight
        assertEquals("mardi", midnight?.label)
        assertEquals(5.25 / 24, midnight!!.position, 1e-12)
        assertEquals("dimanche", timeline("2026-11-21T20:00:00Z").midnight?.label)
        assertEquals("lundi", timeline("2026-11-22T08:00:00Z").midnight?.label)
    }

    @Test
    fun theSwitchToWinterTimeKeepsHoursWhereTheyReallyAre() {
        // Samedi 24 octobre 2026, 20 h 30 (heure d'été). La nuit dure une heure de plus : 6 h tombe 7 h après minuit.
        val saturday = timeline("2026-10-24T18:30:00Z")
        assertTicks(listOf(3.5 to "0 h", 10.5 to "6 h", 16.5 to "12 h", 22.5 to "18 h"), saturday.ticks(6))
        assertEquals("dimanche", saturday.midnight?.label)
        assertEquals("19 h 30", saturday.clock(96), "24 h plus tard, il est une heure de moins à la pendule")
        assertEquals("2 h 30", saturday.clock(24), "première fois, heure d'été")
        assertEquals("2 h 30", saturday.clock(28), "seconde fois, heure d'hiver")
        assertFalse(saturday.isNextDay(13))
        assertTrue(saturday.isNextDay(14))
    }

    @Test
    fun theSwitchToSummerTimeDoesToo() {
        // Samedi 28 mars 2026, 19 h 45 (heure d'hiver). La nuit dure une heure de moins : 6 h tombe 5 h après minuit.
        val saturday = timeline("2026-03-28T18:45:00Z")
        assertTicks(listOf(4.25 to "0 h", 9.25 to "6 h", 15.25 to "12 h", 21.25 to "18 h"), saturday.ticks(6))
        assertEquals("20 h 45", saturday.clock(96))
        assertEquals("1 h 45", saturday.clock(24))
        assertEquals("3 h", saturday.clock(25), "2 h n'existe pas cette nuit-là")
    }

    @Test
    fun aDayOf25HoursMayHaveNoMidnightAhead() {
        // Dimanche 25 octobre 2026, 0 h 30 : le minuit suivant est dans 24 h 30.
        val sunday = timeline("2026-10-24T22:30:00Z")
        assertNull(sunday.midnight)
        assertEquals(listOf("6 h", "12 h", "18 h"), sunday.ticks(6).map { it.label })
    }

    @Test
    fun aStepAskedByAViewStaysWithinTheForecast() {
        assertEquals(listOf(0, 0, 57, 96, 96), listOf(-4, 0, 57, 96, 300).map(VelovForecastTimeline::bounded))
        assertEquals(listOf(0.0, 0.5, 1.0), listOf(0, 48, 96).map(VelovForecastTimeline::position))
    }

    // --- Le panneau du curseur de la carte ([VelovForecastMapPanel]).

    private fun panel(step: Int) = VelovForecastMapPanel.at(VelovForecastSamples.MONDAY_EVENING, step)

    @Test
    fun atRestTheMapSliderInvitesToDrag() {
        val now = panel(0)
        assertEquals("Maintenant", now.title)
        assertEquals("Glissez pour voir la prévision", now.hint)
        assertNull(now.nowButton)
    }

    @Test
    fun onceMovedTheMapSliderNamesTheDayAndTheHour() {
        assertEquals("Aujourd'hui à 19 h 45", panel(4).title)
        assertEquals("Demain à 8 h 30", panel(55).title)
        assertEquals("Demain à 9 h", panel(57).title)
        assertEquals("Demain à 0 h", panel(21).title)
        assertNull(panel(4).hint)
        assertEquals("Maintenant", panel(4).nowButton)
    }

    @Test
    fun theMapSliderIsMarkedEveryThreeHours() {
        assertEquals(listOf("21 h", "0 h", "3 h", "6 h", "9 h", "12 h", "15 h", "18 h"), panel(0).ticks.map { it.label })
        assertEquals(panel(0).ticks, panel(55).ticks, "les repères ne bougent pas avec le curseur")
    }

    @Test
    fun theMapSliderStopsAtBothEnds() {
        assertEquals(panel(0), panel(-2))
        assertEquals(panel(96), panel(120))
        assertEquals("Demain à 18 h 45", panel(96).title)
    }
}
