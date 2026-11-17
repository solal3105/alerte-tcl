package com.alertetcl.shared

import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.VelovChanceLevel
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecastDemo
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** L'intro raconte une matinée : il faut que la démonstration montre vraiment ce que disent ses pages. */
class VelovForecastDemoTest {
    private val sheet = VelovForecastDemo.sheet
    private val filter = VelovForecastDemo.SHEET_FILTER

    @Test
    fun theMapShowsTheRealCountNowAndRangesLater() {
        val now = VelovForecastDemo.markers(0)
        assertEquals(VelovForecastDemo.pins.size, now.size)
        assertTrue(now.all { it.label.toIntOrNull() != null }, "maintenant : le nombre relevé")
        val tomorrow = VelovForecastDemo.markers(VelovForecastDemo.TOUR.last())
        assertTrue(tomorrow.count { "–" in it.label } >= tomorrow.size - 1, "plus tard : des fourchettes")
    }

    @Test
    fun theMapChangesColourAlongTheTour() {
        val colours = VelovForecastDemo.TOUR.map { step -> VelovForecastDemo.markers(step).map { it.availability } }
        val seen = colours.flatten().toSet()
        assertTrue(seen.containsAll(listOf(AvailabilityColor.GREEN, AvailabilityColor.ORANGE, AvailabilityColor.RED)), "les trois couleurs passent")
        val labels = VelovForecastDemo.TOUR.map { step -> VelovForecastDemo.markers(step).map { it.label } }
        assertTrue(labels.zipWithNext().all { (a, b) -> a != b }, "chaque arrêt du curseur change les chiffres")
    }

    @Test
    fun theHomeStationEmptiesInTheMorningAndRefillsInTheEvening() {
        val panel = sheet.panel(filter)
        assertNotNull(panel.risk, "la période à risque est écrite")
        assertTrue(panel.risk!!.startsWith("Souvent vide"), panel.risk!!)
        assertEquals(VelovChanceLevel.UNLIKELY, sheet.readout(filter, 7).chance?.level)
        assertTrue(sheet.readout(filter, 48).chance!!.level.isSafe)
        assertEquals("8 fois sur 10", sheet.readout(filter, 48).reliability)
    }

    @Test
    fun aSaferNeighbourIsOfferedOnlyWhenItHelps() {
        assertTrue(sheet.readout(filter, 7).saferNearby.isNotEmpty(), "plan B quand la station est vide")
        assertTrue(sheet.readout(filter, 48).saferNearby.isEmpty())
        assertNull(sheet.readout(filter, 0).chance)
    }

    @Test
    fun everyKindHasItsOwnCurve() {
        val medians = VelovForecastDemo.KINDS_TOUR.map { kind -> sheet.panel(kind).points.map { it.median } }
        assertEquals(medians.size, medians.toSet().size)
        assertTrue(VelovFilter.STANDS in VelovForecastDemo.KINDS_TOUR)
    }
}
