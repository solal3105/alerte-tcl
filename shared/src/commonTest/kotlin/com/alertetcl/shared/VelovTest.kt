package com.alertetcl.shared

import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.models.VelovTexts
import kotlin.test.Test
import kotlin.test.assertEquals

class VelovTest {
    private fun station(bikes: Int, ebikes: Int = 0, stands: Int = 5, open: Boolean = true) = VelovStation(
        id = 5045, name = "5045 - VALDO / RIVET", address = "Rue Jeunet", lat = 45.75, lng = 4.78,
        bikes = bikes, ebikes = ebikes, mbikes = bikes - ebikes, stands = stands, capacity = 18, open = open, updated = 1_789_473_600L
    )

    @Test
    fun theNameLosesItsNumberAndItsCapitals() {
        assertEquals("Valdo / Rivet", station(3).displayName)
        assertEquals("Saint-Jean / Fourvière", station(3).copy(name = "1001 - SAINT-JEAN / FOURVIÈRE").displayName)
    }

    @Test
    fun availabilityFollowsTheBikesAndTheStationState() {
        assertEquals(AvailabilityColor.GREEN, station(3).availabilityFor(VelovFilter.ALL))
        assertEquals(AvailabilityColor.ORANGE, station(2).availabilityFor(VelovFilter.ALL))
        assertEquals(AvailabilityColor.RED, station(0).availabilityFor(VelovFilter.ALL))
        assertEquals(AvailabilityColor.GRAY, station(8, open = false).availabilityFor(VelovFilter.ALL))
    }

    @Test
    fun eachFilterCountsWhatItAnnounces() {
        val station = station(8, ebikes = 2, stands = 1)
        assertEquals(8, station.shownCount(VelovFilter.ALL))
        assertEquals(6, station.shownCount(VelovFilter.MECHANICAL))
        assertEquals(2, station.shownCount(VelovFilter.ELECTRIC))
        assertEquals(1, station.shownCount(VelovFilter.STANDS))
    }

    @Test
    fun classicBikesAreDeducedWhenTheOperatorOmitsThem() {
        val station = station(8, ebikes = 3).copy(mbikes = 0)
        assertEquals(5, station.shownCount(VelovFilter.MECHANICAL))
    }

    @Test
    fun availabilityFollowsTheChosenFilter() {
        val station = station(8, ebikes = 2, stands = 0)
        assertEquals(AvailabilityColor.GREEN, station.availabilityFor(VelovFilter.ALL))
        assertEquals(AvailabilityColor.ORANGE, station.availabilityFor(VelovFilter.ELECTRIC))
        assertEquals(AvailabilityColor.RED, station.availabilityFor(VelovFilter.STANDS))
        assertEquals(AvailabilityColor.RED, station(5, ebikes = 0).availabilityFor(VelovFilter.ELECTRIC))
        assertEquals(AvailabilityColor.GRAY, station(5, ebikes = 5, open = false).availabilityFor(VelovFilter.ELECTRIC))
    }

    @Test
    fun anUnknownSavedFilterFallsBackToAll() {
        assertEquals(VelovFilter.ELECTRIC, VelovFilter.fromName("ELECTRIC"))
        assertEquals(VelovFilter.ALL, VelovFilter.fromName(null))
        assertEquals(VelovFilter.ALL, VelovFilter.fromName("CARGO"))
    }

    @Test
    fun theStateOfTheMomentFitsOnOneLine() {
        assertEquals("2 classiques · 6 électriques · 5 places", station(8, ebikes = 6).stateText)
        assertEquals("0 classique · 1 électrique · 5 places", station(1, ebikes = 1).stateText)
        assertEquals("Station fermée", station(4, open = false).stateText)
    }

    @Test
    fun theDetailOfTheMomentIsClassicElectricThenDocks() {
        assertEquals(listOf(VelovFilter.MECHANICAL, VelovFilter.ELECTRIC, VelovFilter.STANDS), VelovFilter.detailed)
        val station = station(8, ebikes = 6)
        assertEquals(listOf("2 classiques", "6 électriques", "5 places"), VelovFilter.detailed.map { "${station.shownCount(it)} ${VelovTexts.unit(it, station.shownCount(it))}" })
    }
}
