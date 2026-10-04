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
import kotlin.test.assertFalse
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
    private val stopNames = mapOf(10 to "Perrache", 11 to "Bellecour", 13 to "Guillotière", 14 to "Saxe")

    private fun passage(hhmmss: String, realTime: Boolean = true) =
        Passage(stopId = 13, ligne = "C12", direction = "Saxe", delaipassage = "3 min", heurepassage = "2026-09-15 $hhmmss", type = if (realTime) "E" else "T")

    private fun bus(lastStopId: Int, aimedAtSec: Long, recordedAtSec: Long, delay: Int = 0) = Vehicle(
        id = "bus", latitude = 45.75, longitude = 4.83, bearing = 0.0, lineRef = "", lineName = "C12", vehicleType = VehicleType.BUS,
        destination = "Saxe", direction = "A", delay = delay, recordedAtEpoch = recordedAtSec,
        lastStop = StopInfo(id = "ActIV:StopArea:SP:$lastStopId:SYTRAL", stopRef = "ActIV:StopArea:SP:$lastStopId:SYTRAL",
            stopName = stopNames[lastStopId], aimedArrivalTimeEpoch = aimedAtSec)
    )

    private fun approaching(vehicle: Vehicle, nowMs: Long) =
        StopApproach.approaching(listOf(vehicle), timetable, listOf(13), "Guillotière", nowMs)

    private fun group(passages: List<Passage>) = PassageGroup("C12", "A", "Saxe", 13, passages)

    @Test
    fun aStaleAnnouncementGivesWayToTheBusOneStopAway() {
        // 14:13:30 : TCL annonce toujours « 14:17 » (délai figé) ; le dernier arrêt atteint par le bus est
        // Bellecour, à l'heure : Guillotière est le suivant.
        val now = at(13.5)
        val approach = approaching(bus(11, t0Sec + 10 * 60, recordedAtSec = now / 1000 - 20), now)
        val board = StopBoard.board(group(listOf(passage("14:17:00"), passage("14:44:00"))), approach, timetable, guillotiere, now)
        val first = board.first!!
        assertEquals(PassagePhase.APPROACHING, first.phase)
        assertEquals("À l'approche", first.headline(now))
        assertEquals("14:14", first.caption(now))
        assertEquals("Dernier arrêt atteint : Bellecour, le vôtre est le suivant", first.location)
        assertEquals("14:14", PassageTexts.headlineDetail(board, now))
        assertEquals("14:14 · Dernier arrêt atteint : Bellecour, le vôtre est le suivant", PassageTexts.rowDetail(first, now))
        assertEquals("Dernier arrêt atteint : Bellecour", first.approach?.vehicle?.lastStopLine)
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
    fun aBusComingToYourStopIsKeptWhenTclNoLongerAnnouncesIt() {
        // 14:12 : dernier arrêt atteint Bellecour (14:10) ; TCL n'annonce plus que 14:44.
        val now = at(12.0)
        val approach = approaching(bus(11, t0Sec + 10 * 60, recordedAtSec = now / 1000 - 10), now)
        val first = StopBoard.upcoming(listOf(passage("14:44:00")), approach, timetable, guillotiere, now).first()
        assertEquals(PassagePhase.APPROACHING, first.phase)
        assertEquals("Dernier arrêt atteint : Bellecour, le vôtre est le suivant", first.location)
    }

    @Test
    fun aBusWhoseLastStopIsYoursHasAlreadyBeenThere() {
        // Le dernier arrêt atteint est Guillotière, l'arrêt de l'usager : avant son heure (en avance) comme
        // après, le bus y est déjà passé. Sa position a au moins 45 s de retard : on ne dit jamais qu'il y est.
        for (minutes in listOf(13.0, 14.5)) {
            val now = at(minutes)
            val bus = bus(13, t0Sec + 14 * 60, recordedAtSec = now / 1000 - 10)
            assertTrue(approaching(bus, now).isEmpty())
            assertEquals("Dernier arrêt atteint : Guillotière", bus.lastStopLine)
        }
    }

    @Test
    fun aBusWaitingForItsCourseIsNotApproaching() {
        // 14:30 : le bus attend à Bellecour le départ de sa course, qui n'y part qu'à 14:40 (Guillotière 14:44).
        val now = at(30.0)
        val approach = approaching(bus(11, t0Sec + 40 * 60, recordedAtSec = now / 1000 - 10), now)
        val first = StopBoard.upcoming(listOf(passage("14:44:00")), approach, timetable, guillotiere, now).first()
        assertEquals(PassagePhase.LIVE, first.phase)
        assertEquals("14 min", first.headline(now))
        assertEquals("Dernier arrêt atteint : Bellecour, le vôtre est le suivant", first.location)
        // Sans annonce TCL, il n'a pas de délai à lui : la fiche horaire donne le passage.
        val alone = StopBoard.upcoming(emptyList(), approach, timetable, guillotiere, now).first()
        assertEquals(PassagePhase.SCHEDULED, alone.phase)
        assertNull(alone.approach)
    }

    @Test
    fun anAgingPositionIsShownAsApproximate() {
        val now = at(0.0)
        val approach = approaching(bus(10, t0Sec + 5 * 60, recordedAtSec = now / 1000 - 70), now)
        val first = StopBoard.upcoming(listOf(passage("14:14:00")), approach, timetable, guillotiere, now).first()
        assertEquals("~14 min", first.headline(now))
        assertEquals("Dernier arrêt atteint : Perrache, encore 1 arrêt avant le vôtre", first.location)
        assertEquals("position d'il y a 1 min 10", first.approach?.vehicle?.stalenessLine(now))
    }

    @Test
    fun aBusThatCannotBeTiedToAnAnnouncementGetsNoNumberOfItsOwn() {
        val now = at(0.0)
        // Course reconnue (14:14 à Guillotière) que TCL n'annonce pas : seule l'annonce de 14:44 compte.
        val known = approaching(bus(10, t0Sec + 5 * 60, recordedAtSec = now / 1000 - 10), now)
        val upcoming = StopBoard.upcoming(listOf(passage("14:44:00")), known, timetable, guillotiere, now)
        assertEquals("44 min", upcoming.first().headline(now))
        assertTrue(upcoming.none { it.approach != null })
        // Course inconnue (rien ne part de Perrache à 14:07) : rien ne la relie au passage de 14:03.
        val unknown = approaching(bus(10, t0Sec + 7 * 60, recordedAtSec = now / 1000 - 10), now)
        assertNull(StopBoard.upcoming(listOf(passage("14:03:00")), unknown, timetable, guillotiere, now).first().approach)
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
        assertEquals("prévu 14:44 · Dernier passage", PassageTexts.headlineDetail(lastBoard, late))
        assertEquals("Ensuite demain 14:14 · demain 14:44", PassageTexts.thenLine(lastBoard))
    }

    @Test
    fun withoutAnythingTheCardSaysWhy() {
        val empty = StopBoard.board(group(emptyList()), emptyList(), null, emptyList(), at(0.0))
        assertNull(empty.first)
        assertNull(PassageTexts.headlineDetail(empty, at(0.0)))
        assertEquals(PassageTexts.NONE_ANNOUNCED, PassageTexts.noPassage(timetableKnown = false))
        assertEquals(PassageTexts.NONE_PLANNED, PassageTexts.noPassage(timetableKnown = true))
    }

    @Test
    fun theEndOfTheLineOnlyArrives() {
        assertTrue(StopBoard.isArrivalOnly(timetable, listOf(14), "Saxe"))
        assertFalse(StopBoard.isArrivalOnly(timetable, listOf(13), "Guillotière"))
        assertFalse(StopBoard.isArrivalOnly(timetable, listOf(999), "Ailleurs"))
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
