package com.alertetcl.shared

import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.VelovStation
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
        assertEquals(AvailabilityColor.GREEN, station(3).availability)
        assertEquals(AvailabilityColor.ORANGE, station(2).availability)
        assertEquals(AvailabilityColor.RED, station(0).availability)
        assertEquals(AvailabilityColor.GRAY, station(8, open = false).availability)
    }

    @Test
    fun theElectricFilterCountsOnlyElectricBikes() {
        val station = station(8, ebikes = 2)
        assertEquals(8, station.shownBikes(false))
        assertEquals(2, station.shownBikes(true))
        assertEquals(AvailabilityColor.GREEN, station.availabilityFor(false))
        assertEquals(AvailabilityColor.ORANGE, station.availabilityFor(true))
        assertEquals(AvailabilityColor.RED, station(5, ebikes = 0).availabilityFor(true))
        assertEquals(AvailabilityColor.GRAY, station(5, ebikes = 5, open = false).availabilityFor(true))
    }

    @Test
    fun textsAreWrittenInFullSentences() {
        assertEquals("8 vélos disponibles, dont 6 électriques et 2 mécaniques", station(8, ebikes = 6).bikesText)
        assertEquals("1 vélo disponible, dont 1 électrique et 0 mécanique", station(1, ebikes = 1).bikesText)
        assertEquals("Aucun vélo disponible", station(0).bikesText)
        assertEquals("Station fermée", station(4, open = false).bikesText)
        assertEquals("5 places libres pour rendre un vélo", station(3).standsText)
        assertEquals("Aucune place libre pour rendre un vélo", station(3, stands = 0).standsText)
        assertEquals("Mis à jour il y a 2 min", station(3).updatedText((1_789_473_600L + 120) * 1000))
    }
}
