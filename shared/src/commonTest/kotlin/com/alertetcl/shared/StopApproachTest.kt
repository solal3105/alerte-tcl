package com.alertetcl.shared

import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.StopApproach
import com.alertetcl.shared.models.StopInfo
import com.alertetcl.shared.models.TimetableStop
import com.alertetcl.shared.models.TimetableTrip
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class StopApproachTest {
    // Mardi 15 septembre 2026, 14:00:00 à Paris (12:00 UTC).
    private val nowMs = 1_789_473_600_000L
    private val nowSec = nowMs / 1000

    /** Ligne C12 sens A : Perrache (10) → Bellecour (11, quais 11 et 12) → Guillotière (13) → Saxe (14). */
    private val timetable = LineTimetable(
        line = "C12", key = "C12", dir = "A", validFrom = "2026-09-14", validTo = "2026-12-01",
        stops = listOf(TimetableStop(10, "Perrache"), TimetableStop(11, "Bellecour"), TimetableStop(12, "Bellecour"),
            TimetableStop(13, "Guillotière"), TimetableStop(14, "Saxe")),
        patterns = listOf(listOf(0, 1, 3, 4), listOf(0, 2, 3, 4)),
        services = listOf(listOf(0, 1, 2, 3, 4, 5, 6)),
        // 14:05 à Perrache, 14:10 à Bellecour, 14:14 à Guillotière, 14:20 à Saxe ; puis une course à 14:35.
        trips = listOf(
            TimetableTrip(p = 0, s = 0, t = listOf(845, 850, 854, 860)),
            TimetableTrip(p = 1, s = 0, t = listOf(875, 880, 884, 890))
        )
    )

    private fun vehicle(id: String, nextStopId: Int, aimedAtSec: Long?, delay: Int = 0, direction: String = "A", line: String = "C12") = Vehicle(
        id = id, latitude = 45.75, longitude = 4.83, bearing = 0.0, lineRef = "", lineName = line, vehicleType = VehicleType.BUS,
        destination = "Saxe", direction = direction, delay = delay, recordedAtEpoch = nowSec - 40,
        nextStop = StopInfo(id = "ActIV:StopArea:SP:$nextStopId:SYTRAL", stopRef = "ActIV:StopArea:SP:$nextStopId:SYTRAL",
            aimedArrivalTimeEpoch = aimedAtSec)
    )

    @Test
    fun aRecognisedTripGivesTheStopCountAndAnArrivalCorrectedByTheDelay() {
        // Prochain arrêt Perrache à 14:05 prévu, 2 min de retard : à Guillotière, 14:14 + 2 min.
        val bus = vehicle("bus-1", nextStopId = 10, aimedAtSec = nowSec + 5 * 60, delay = 120)
        val result = StopApproach.approaching(listOf(bus), timetable, stopIds = listOf(13), stopName = "Guillotière", nowEpochMs = nowMs)
        assertEquals(1, result.size)
        val approach = result[0]
        assertEquals(2, approach.stopsBefore)
        assertEquals("14:14", approach.scheduledTime)
        assertEquals(nowSec + 14 * 60 + 120, approach.estimatedArrivalEpoch)
        assertEquals("À 2 arrêts", approach.stopsText)
        assertEquals("dans 16 min", approach.arrivalText(nowMs))
        assertEquals("position transmise il y a 40 s", approach.positionText(nowMs))
    }

    @Test
    fun theStopItselfAsNextStopCountsAsZeroAndAPassedStopIsIgnored() {
        val arriving = vehicle("bus-2", nextStopId = 13, aimedAtSec = nowSec + 60)
        val gone = vehicle("bus-3", nextStopId = 14, aimedAtSec = nowSec + 6 * 60)
        val result = StopApproach.approaching(listOf(gone, arriving), timetable, listOf(13), "Guillotière", nowMs)
        assertEquals(listOf("bus-2"), result.map { it.vehicle.id })
        assertEquals("Au prochain arrêt", result[0].stopsText)
    }

    @Test
    fun otherLinesAndTheOtherDirectionAreIgnored() {
        val otherLine = vehicle("bus-4", nextStopId = 10, aimedAtSec = nowSec + 5 * 60, line = "C13")
        val otherDirection = vehicle("bus-5", nextStopId = 10, aimedAtSec = nowSec + 5 * 60, direction = "R")
        val unknownDirection = vehicle("bus-6", nextStopId = 10, aimedAtSec = nowSec + 5 * 60, direction = "")
        val result = StopApproach.approaching(listOf(otherLine, otherDirection, unknownDirection), timetable, listOf(13), "Guillotière", nowMs)
        assertEquals(listOf("bus-6"), result.map { it.vehicle.id })
    }

    @Test
    fun anUnrecognisedTripStillCountsStopsButGivesNoTime() {
        // 14:07 prévu à Perrache : aucune course ne passe à cette minute.
        val bus = vehicle("bus-7", nextStopId = 10, aimedAtSec = nowSec + 7 * 60)
        val result = StopApproach.approaching(listOf(bus), timetable, listOf(13), "Guillotière", nowMs)
        assertEquals(1, result.size)
        assertEquals(2, result[0].stopsBefore)
        assertNull(result[0].estimatedArrivalEpoch)
        assertNull(result[0].arrivalText(nowMs))
    }

    @Test
    fun platformsOfTheSameStopAreOneStopAndTheClosestVehicleComesFirst() {
        // Quai 12 de Bellecour desservi par le motif 1 (départ de Perrache à 14:35, Bellecour à 14:40), quai 11 par le motif 0.
        val far = vehicle("bus-8", nextStopId = 10, aimedAtSec = nowSec + 35 * 60)
        val near = vehicle("bus-9", nextStopId = 11, aimedAtSec = nowSec + 10 * 60)
        val result = StopApproach.approaching(listOf(far, near), timetable, stopIds = listOf(11, 12), stopName = "Bellecour", nowMs)
        assertEquals(listOf("bus-9", "bus-8"), result.map { it.vehicle.id })
        assertEquals(0, result[0].stopsBefore)
        assertEquals(1, result[1].stopsBefore)
        assertEquals("14:40", result[1].scheduledTime)
    }

    @Test
    fun anImminentArrivalIsSaidSo() {
        val bus = vehicle("bus-10", nextStopId = 13, aimedAtSec = nowSec + 14 * 60)
        val result = StopApproach.approaching(listOf(bus), timetable, listOf(13), "Guillotière", nowEpochMs = nowMs + 14 * 60 * 1000 - 30_000)
        assertEquals("imminent", result[0].arrivalText(nowMs + 14 * 60 * 1000 - 30_000))
        assertTrue(StopApproach.NOTE.contains("pas un suivi en direct"))
    }
}
