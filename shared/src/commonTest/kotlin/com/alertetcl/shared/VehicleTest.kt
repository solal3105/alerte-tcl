package com.alertetcl.shared

import com.alertetcl.shared.models.PositionFreshness
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VehicleTest {
    private val nowMs = 1_800_000_000_000L

    private fun vehicle(ageSeconds: Long?) = Vehicle(
        id = "ActIV:Vehicle:Bus:2101:LOC", latitude = 45.75, longitude = 4.83, bearing = 0.0,
        lineRef = "ActIV:Line::C12:SYTRAL", lineName = "C12", vehicleType = VehicleType.BUS,
        destination = "Hôpital Feyzin Vénissieux", delay = 0,
        recordedAtEpoch = ageSeconds?.let { nowMs / 1000 - it }
    )

    @Test
    fun aVehicleLeavesTheMapAfterNinetySecondsWithoutNews() {
        assertTrue(vehicle(ageSeconds = 89).isShownOnMap(nowMs))
        assertFalse(vehicle(ageSeconds = Vehicle.HIDE_AFTER_SECONDS).isShownOnMap(nowMs))
        assertFalse(vehicle(ageSeconds = 600).isShownOnMap(nowMs))
    }

    @Test
    fun aVehicleWithoutTimestampStaysOnTheMap() {
        assertTrue(vehicle(ageSeconds = null).isShownOnMap(nowMs))
        assertEquals(PositionFreshness.FRESH, vehicle(ageSeconds = null).positionFreshness(nowMs))
    }

    @Test
    fun freshnessFollowsTheAgeOfThePosition() {
        assertEquals(PositionFreshness.FRESH, vehicle(ageSeconds = 44).positionFreshness(nowMs))
        assertEquals(PositionFreshness.AGING, vehicle(ageSeconds = 45).positionFreshness(nowMs))
        assertEquals(PositionFreshness.AGING, vehicle(ageSeconds = 89).positionFreshness(nowMs))
        assertEquals(PositionFreshness.STALE, vehicle(ageSeconds = 90).positionFreshness(nowMs))
    }
}
