package com.alertetcl.shared

import com.alertetcl.shared.models.VehicleTexts
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VehicleTextsTest {
    @Test
    fun anEcartUnderAMinuteIsAnnouncedOnTime() {
        assertEquals("À l'heure", VehicleTexts.punctuality(0))
        assertEquals("À l'heure", VehicleTexts.punctuality(45))
        assertEquals("À l'heure", VehicleTexts.punctuality(-60))
        assertFalse(VehicleTexts.isOffSchedule(-60))
    }

    @Test
    fun aDelayIsNamedAndRoundedToTheNearestMinute() {
        assertEquals("1 min de retard", VehicleTexts.punctuality(70))
        assertEquals("2 min de retard", VehicleTexts.punctuality(100))
        assertTrue(VehicleTexts.isOffSchedule(100))
    }

    @Test
    fun beingAheadIsNamedToo() {
        assertEquals("3 min d'avance", VehicleTexts.punctuality(-160))
        assertTrue(VehicleTexts.isOffSchedule(-160))
    }

    @Test
    fun whereTheVehicleIsIsSaidInOneSentence() {
        assertEquals("Prochain arrêt Génovéfains à 22:53", VehicleTexts.nextStop("Génovéfains", "22:53"))
        assertEquals("À l'arrêt Génovéfains", VehicleTexts.atStop("Génovéfains"))
        assertEquals("Vient de passer Génovéfains", VehicleTexts.justPassed("Génovéfains"))
    }
}
