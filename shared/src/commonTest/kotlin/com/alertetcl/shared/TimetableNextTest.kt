package com.alertetcl.shared

import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.TimetableNext
import com.alertetcl.shared.models.TimetableStop
import com.alertetcl.shared.models.TimetableTrip
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class TimetableNextTest {
    private val zone = "Europe/Paris"
    private val timetable = LineTimetable(
        line = "C3", key = "C3", dir = "A", validFrom = "2026-09-20", validTo = "2026-09-27",
        stops = listOf(TimetableStop(100, "Gratte-Ciel"), TimetableStop(200, "Gare Saint-Paul")),
        patterns = listOf(listOf(0, 1)),
        services = listOf(listOf(0, 1, 2)),
        trips = listOf(TimetableTrip(0, 0, listOf(300, 320)), TimetableTrip(0, 0, listOf(1380, 1400)), TimetableTrip(0, 0, listOf(1470, 1490)))
    )

    private fun at(day: Int, hour: Int, minute: Int): Long =
        LocalDateTime(2026, 9, day, hour, minute).toInstant(TimeZone.of(zone)).toEpochMilliseconds()

    @Test
    fun ilResteDesDepartsCeSoir() {
        val next = TimetableNext.upcoming(timetable, listOf(100), "Gratte-Ciel", at(20, 23, 30), zone)!!
        assertFalse(next.isTomorrow)
        assertEquals(listOf("00:30"), next.departures.map { it.time })
    }

    @Test
    fun apresLeDernierOnAnnonceLesPremiersDeDemain() {
        val next = TimetableNext.upcoming(timetable, listOf(100), "Gratte-Ciel", at(21, 1, 0), zone)!!
        assertTrue(next.isTomorrow)
        assertEquals("2026-09-21", next.isoDate)
        assertEquals(listOf("05:00", "23:00", "00:30"), next.departures.map { it.time })
    }

    @Test
    fun auTerminusDuSensRienNestPropose() {
        assertNull(TimetableNext.upcoming(timetable, listOf(200), "Gare Saint-Paul", at(20, 12, 0), zone))
    }

    @Test
    fun leTerminusDuSensNeFaitQuArriver() {
        assertTrue(TimetableNext.isArrivalOnly(timetable, listOf(200), "Gare Saint-Paul"))
        assertFalse(TimetableNext.isArrivalOnly(timetable, listOf(100), "Gratte-Ciel"))
        assertFalse(TimetableNext.isArrivalOnly(timetable, listOf(999), "Ailleurs"))
    }

    @Test
    fun arretInconnuDeLaFiche() {
        assertNull(TimetableNext.upcoming(timetable, listOf(999), "Ailleurs", at(20, 12, 0), zone))
    }
}
