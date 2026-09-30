package com.alertetcl.shared

import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.models.PassageGroup
import com.alertetcl.shared.models.PassagePhase
import com.alertetcl.shared.models.PassageTexts
import com.alertetcl.shared.models.StopApproach
import com.alertetcl.shared.models.StopBoard
import com.alertetcl.shared.models.StopInfo
import com.alertetcl.shared.models.TimetableStop
import com.alertetcl.shared.models.TimetableTrip
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class StopBoardTest {
    // Mardi 15 septembre 2026, 14:00:00 à Paris (12:00 UTC).
    private val t0 = 1_789_473_600_000L
    private val t0Sec = t0 / 1000
    private fun at(minutes: Double): Long = t0 + (minutes * 60_000).toLong()

    /** C12 sens A : Perrache (10) → Bellecour (11) → Guillotière (13) → Saxe (14), à 14:05/14:10/14:14/14:20 puis 14:35/14:40/14:44/14:50. */
    private val timetable = LineTimetable(
        line = "C12", key = "C12", dir = "A", validFrom = "2026-09-14", validTo = "2026-12-01",
        stops = listOf(TimetableStop(10, "Perrache"), TimetableStop(11, "Bellecour"), TimetableStop(13, "Guillotière"), TimetableStop(14, "Saxe")),
        patterns = listOf(listOf(0, 1, 2, 3)),
        services = listOf(listOf(0, 1, 2, 3, 4, 5, 6)),
        trips = listOf(TimetableTrip(p = 0, s = 0, t = listOf(845, 850, 854, 860)), TimetableTrip(p = 0, s = 0, t = listOf(875, 880, 884, 890)))
    )
    private val guillotiere = listOf(2)

    private fun passage(hhmmss: String, realTime: Boolean = true) =
        Passage(stopId = 13, ligne = "C12", direction = "Saxe", delaipassage = "3 min", heurepassage = "2026-09-15 $hhmmss", type = if (realTime) "E" else "T")

    private fun bus(nextStopId: Int, aimedAtSec: Long, recordedAtSec: Long, delay: Int = 0, distance: Int? = null) = Vehicle(
        id = "bus", latitude = 45.75, longitude = 4.83, bearing = 0.0, lineRef = "", lineName = "C12", vehicleType = VehicleType.BUS,
        destination = "Saxe", direction = "A", delay = delay, recordedAtEpoch = recordedAtSec,
        nextStop = StopInfo(id = "ActIV:StopArea:SP:$nextStopId:SYTRAL", stopRef = "ActIV:StopArea:SP:$nextStopId:SYTRAL",
            stopName = if (nextStopId == 11) "Bellecour" else "Guillotière", aimedArrivalTimeEpoch = aimedAtSec, distanceFromStop = distance)
    )

    private fun approaching(vehicle: Vehicle, nowMs: Long) =
        StopApproach.approaching(listOf(vehicle), timetable, listOf(13), "Guillotière", nowMs)

    private fun group(passages: List<Passage>) = PassageGroup("C12", "A", "Saxe", 13, passages)

    @Test
    fun aStaleAnnouncementGivesWayToTheBusOneStopAway() {
        // 14:13:30 : TCL annonce toujours « 14:17 » (délai figé), le bus est attendu à Bellecour à 14:10, à l'heure.
        val now = at(13.5)
        val approach = approaching(bus(11, t0Sec + 10 * 60, recordedAtSec = now / 1000 - 20), now)
        val board = StopBoard.board(group(listOf(passage("14:17:00"), passage("14:44:00"))), approach, timetable, guillotiere, now)
        val first = board.first!!
        assertEquals(PassagePhase.APPROACHING, first.phase)
        assertEquals("À l'approche", first.headline(now))
        assertEquals("14:14", first.caption(now))
        assertEquals("Vers Bellecour, l'arrêt d'avant", first.location)
        assertNull(first.approach?.vehicle?.stalenessLine(now))
        // Le bus reconnu a pris l'annonce de 14:17 : il n'est compté qu'une fois.
        assertTrue(board.following.none { it.approach != null })
        assertEquals(854, first.scheduledMinutes)
    }

    @Test
    fun theWaitCountsDownWithTheClockBetweenTwoRefreshes() {
        val passages = listOf(passage("14:10:00"))
        fun first(minutes: Double) = StopBoard.upcoming(passages, emptyList(), null, emptyList(), at(minutes)).firstOrNull()
        assertEquals("10 min", first(0.0)?.headline(at(0.0)))
        assertEquals("3 min", first(7.0)?.headline(at(7.0)))
        assertEquals(PassagePhase.APPROACHING, first(9.5)?.phase)
        // Dépassée depuis une minute : le bus n'est peut-être pas encore passé.
        assertEquals(PassagePhase.APPROACHING, first(11.0)?.phase)
        assertNull(first(13.0))
    }

    @Test
    fun aBusStillComingIsKeptWhenTcl_noLongerAnnouncesIt() {
        val now = at(14.5)
        val approach = approaching(bus(13, t0Sec + 14 * 60, recordedAtSec = now / 1000 - 10, distance = 250), now)
        val first = StopBoard.upcoming(listOf(passage("14:44:00")), approach, timetable, guillotiere, now).first()
        assertEquals(PassagePhase.APPROACHING, first.phase)
        assertEquals(PassageTexts.NEXT_IS_YOURS, first.location)
        assertNull(first.caption(now), "l'heure prévue est passée : elle n'est pas présentée comme à venir")
    }

    @Test
    fun aBusAFewMetresAwayIsAtTheStop() {
        val now = at(14.0)
        val approach = approaching(bus(13, t0Sec + 14 * 60, recordedAtSec = now / 1000 - 10, distance = 12), now)
        val first = StopBoard.upcoming(emptyList(), approach, timetable, guillotiere, now).first()
        assertEquals(PassagePhase.AT_STOP, first.phase)
        assertEquals("À l'arrêt", first.headline(now))
        assertEquals(PassageTexts.AT_YOUR_STOP, first.location)
    }

    @Test
    fun anAgingPositionIsShownAsApproximate() {
        val now = at(0.0)
        val approach = approaching(bus(10, t0Sec + 5 * 60, recordedAtSec = now / 1000 - 70), now)
        val first = StopBoard.upcoming(emptyList(), approach, timetable, guillotiere, now).first()
        assertEquals("~14 min", first.headline(now))
        assertEquals("position d'il y a 1 min 10", first.approach?.vehicle?.stalenessLine(now))
    }

    @Test
    fun withoutAnnouncementTheTimetableTakesOverThenTomorrow() {
        val now = at(20.0)
        val upcoming = StopBoard.upcoming(emptyList(), emptyList(), timetable, guillotiere, now)
        assertEquals(listOf(PassagePhase.SCHEDULED, PassagePhase.SCHEDULED, PassagePhase.SCHEDULED), upcoming.map { it.phase })
        assertEquals("24 min", upcoming[0].headline(now))
        assertEquals("prévu 14:44", upcoming[0].caption(now))
        assertEquals(listOf(false, true, true), upcoming.map { it.isTomorrow })
        assertEquals("14:14", upcoming[1].headline(now))
        assertEquals("demain", upcoming[1].caption(now))
    }

    @Test
    fun theLastDepartureOfTheDayIsNamed() {
        val now = at(0.0)
        val board = StopBoard.board(group(listOf(passage("14:15:00"))), emptyList(), timetable, guillotiere, now)
        assertEquals("15 min", board.first?.headline(now))
        assertTrue(board.following.isEmpty())
        assertEquals("Dernier 14:44", PassageTexts.thenLine(board))

        val late = at(40.0)
        val lastBoard = StopBoard.board(group(emptyList()), emptyList(), timetable, guillotiere, late)
        assertTrue(lastBoard.firstIsLast)
        assertEquals("Ensuite demain 14:14 · demain 14:44", PassageTexts.thenLine(lastBoard))
    }

    @Test
    fun theGridGreysOnlyWhatHasReallyGone() {
        // 14:15 : le bus de 14:14 a deux minutes de retard, il n'est pas passé.
        val now = at(15.0)
        val departures = timetable.departures(guillotiere, "2026-09-15")
        val upcoming = StopBoard.upcoming(listOf(passage("14:16:00")), emptyList(), timetable, guillotiere, now)
        val grid = StopBoard.grid(departures, upcoming, now)
        assertEquals(0, grid.nextIndex)
        assertEquals(PassagePhase.LIVE, grid.phaseOf(0))
        assertEquals(PassagePhase.SCHEDULED, grid.phaseOf(1))

        // 14:30, plus rien d'annoncé pour 14:14 : il est passé.
        val later = at(30.0)
        val gone = StopBoard.grid(departures, StopBoard.upcoming(emptyList(), emptyList(), timetable, guillotiere, later), later)
        assertEquals(PassagePhase.DEPARTED, gone.phaseOf(0))
        assertEquals(1, gone.nextIndex)
    }
}
