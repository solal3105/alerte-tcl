package com.alertetcl.shared

import com.alertetcl.shared.models.VehicleTexts
import kotlin.test.Test
import kotlin.test.assertEquals

class VehicleTextsTest {
    @Test
    fun anEcartUnderAMinuteIsAnnouncedOnTime() {
        assertEquals("à l'heure", VehicleTexts.punctualityAmount(0))
        assertEquals("à l'heure", VehicleTexts.punctualityAmount(45))
        assertEquals("à l'heure", VehicleTexts.punctualityAmount(-60))
        assertEquals("ponctualité", VehicleTexts.punctualityCaption(45))
        assertEquals("À l'heure", VehicleTexts.punctuality(45))
    }

    @Test
    fun aDelayIsNamedAndRoundedToTheNearestMinute() {
        assertEquals("1 min", VehicleTexts.punctualityAmount(70))
        assertEquals("2 min", VehicleTexts.punctualityAmount(100))
        assertEquals("de retard", VehicleTexts.punctualityCaption(100))
        assertEquals("2 min de retard", VehicleTexts.punctuality(100))
    }

    @Test
    fun beingAheadIsNamedToo() {
        assertEquals("3 min", VehicleTexts.punctualityAmount(-160))
        assertEquals("d'avance", VehicleTexts.punctualityCaption(-160))
        assertEquals("3 min d'avance", VehicleTexts.punctuality(-160))
    }

    @Test
    fun theArrivalTimeSaysWhereItArrives() {
        assertEquals("arrivée à Bellecour", VehicleTexts.arrivalCaption("Bellecour"))
    }
}
