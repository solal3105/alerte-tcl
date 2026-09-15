package com.alertetcl.shared

import com.alertetcl.shared.models.DirectionMatching
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.LinePalette
import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.StopLineFocus
import com.alertetcl.shared.models.TimetableIndex
import com.alertetcl.shared.models.TimetableKeys
import com.alertetcl.shared.models.TimetableTime
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import com.alertetcl.shared.network.HttpClientProvider
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import com.alertetcl.shared.models.TransportMode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class TimetableTest {

    /** Fiche minimale au format produit par horaires/build_timetables.py. */
    private val sampleJson = """
        {"format":1,"line":"C3","key":"C3","dir":"A","mode":"bus","headsign":"Vaulx-en-Velin La Grappinière",
         "validFrom":"2026-09-15","validTo":"2026-09-21",
         "stops":[{"id":100,"name":"Gare Saint-Paul"},{"id":200,"name":"Bellecour"},{"id":300,"name":"Part-Dieu Vivier Merle"},{"id":400,"name":"Vaulx-en-Velin La Grappinière"}],
         "patterns":[[0,1,2,3],[0,1,2]],
         "services":[[0,1,2,3,4],[5,6]],
         "trips":[{"p":0,"s":0,"t":[300,310,320,340]},{"p":1,"s":0,"t":[1430,1440,1450]},{"p":0,"s":1,"t":[600,612,625,650]}]}
    """.trimIndent()

    private val timetable: LineTimetable = HttpClientProvider.json.decodeFromString(LineTimetable.serializer(), sampleJson)

    @Test
    fun decodeAndValidity() {
        assertEquals("C3", timetable.line)
        assertEquals(4, timetable.stops.size)
        assertTrue(timetable.isValidOn(LocalDate(2026, 9, 15)))
        assertTrue(timetable.isValidOn(LocalDate(2026, 9, 21)))
        assertFalse(timetable.isValidOn(LocalDate(2026, 9, 22)))
        assertFalse(timetable.isValidOn(LocalDate(2026, 9, 14)))
    }

    @Test
    fun departuresFollowServiceCalendar() {
        val weekday = timetable.departures(listOf(1), LocalDate(2026, 9, 16))
        assertEquals(listOf(310, 1440), weekday.map { it.minutes })
        assertEquals("Vaulx-en-Velin La Grappinière", weekday[0].terminus)
        assertEquals("Part-Dieu Vivier Merle", weekday[1].terminus, "course partielle : terminus réel")
        assertFalse(weekday[0].isTerminus)

        val weekend = timetable.departures(listOf(1), LocalDate(2026, 9, 20))
        assertEquals(listOf(612), weekend.map { it.minutes })

        val outside = timetable.departures(listOf(1), LocalDate(2026, 10, 1))
        assertTrue(outside.isEmpty())
    }

    @Test
    fun terminusArrivalIsFlagged() {
        val atTerminus = timetable.departures(listOf(3), LocalDate(2026, 9, 15))
        assertEquals(1, atTerminus.size)
        assertTrue(atTerminus[0].isTerminus)
        val atPartialTerminus = timetable.departures(listOf(2), LocalDate(2026, 9, 15))
        assertEquals(listOf(false, true), atPartialTerminus.map { it.isTerminus })
    }

    @Test
    fun stopLookupByIdThenByName() {
        assertEquals(listOf(1), timetable.stopIndexes(setOf(200, 999)))
        assertEquals(listOf(2), timetable.stopIndexes(setOf(999), "Part Dieu Vivier-Merle"))
        assertTrue(timetable.stopIndexes(setOf(999), "Inconnu").isEmpty())
    }

    @Test
    fun callsOfATrip() {
        val calls = timetable.calls(1)
        assertEquals(listOf("Gare Saint-Paul", "Bellecour", "Part-Dieu Vivier Merle"), calls.map { it.stop.name })
        assertEquals(listOf("23:50", "00:00", "00:10"), calls.map { it.time })
        assertTrue(timetable.calls(42).isEmpty())
    }

    @Test
    fun timeFormattingAndServiceDay() {
        assertEquals("05:00", TimetableTime.format(300))
        assertEquals("01:05", TimetableTime.format(1505))
        assertTrue(TimetableTime.isAfterMidnight(1440))
        assertEquals(LocalDate(2026, 9, 14), TimetableTime.serviceDate(LocalDateTime(2026, 9, 15, 1, 30)))
        assertEquals(LocalDate(2026, 9, 15), TimetableTime.serviceDate(LocalDateTime(2026, 9, 15, 4, 0)))
        assertEquals(1440 + 90, TimetableTime.serviceMinutes(LocalDateTime(2026, 9, 15, 1, 30)))
        assertEquals(8 * 60 + 5, TimetableTime.serviceMinutes(LocalDateTime(2026, 9, 15, 8, 5)))
    }

    @Test
    fun lineKeys() {
        assertEquals("C3", TimetableKeys.keyFor("c3"))
        assertEquals("RHNEXPRESS", TimetableKeys.keyFor("Rhônexpress"), "les lettres accentuées sont ignorées, comme dans le script Python")
        assertEquals("JD975", TimetableKeys.keyFor(" JD975 "))
        val index = HttpClientProvider.json.decodeFromString(
            TimetableIndex.serializer(),
            """{"format":1,"validFrom":"2026-09-15","validTo":"2026-10-01","lines":[{"line":"C3","key":"C3","mode":"bus","directions":[{"dir":"A","headsign":"X"}]}]}"""
        )
        assertEquals("C3", index.line("c3")?.line)
        assertNull(index.line("C4"))
    }

    @Test
    fun directionMatching() {
        assertEquals("gareparthdieuvmerle".replace("h", ""), DirectionMatching.normalize("Gare Part-Dieu V.Merle"))
        assertTrue(DirectionMatching.namesMatch("Vaulx-en-Velin La Soie", "Vaulx en Velin la soie"))
        assertTrue(DirectionMatching.namesMatch("St-Genis-Laval Hôp. Sud", "St-Genis-Laval Hôpital Lyon Sud"))
        assertTrue(DirectionMatching.namesMatch("Hôp. Feyzin Vénissieux", "Hôpital Feyzin Vénissieux"), "abréviation mot à mot")
        assertFalse(DirectionMatching.namesMatch("Gare de Vaise", "Gare de Vénissieux"))
        assertFalse(DirectionMatching.namesMatch("Perrache", "Bellecour"))
        assertFalse(DirectionMatching.namesMatch("", "Bellecour"))

        val termini = mapOf("C3|A" to "Vaulx-en-Velin La Grappinière", "C3|R" to "Gare Saint-Paul")
        assertEquals("A", DirectionMatching.resolveDirection("C3", "Vaulx-en-Velin La Grappinière", termini))
        assertEquals("R", DirectionMatching.resolveDirection("C3", "Gare St-Paul".replace("St", "Saint"), termini))
        assertNull(DirectionMatching.resolveDirection("C3", "Part-Dieu", termini))
        assertNull(DirectionMatching.resolveDirection("C4", "Gare Saint-Paul", termini))

        assertEquals("A", DirectionMatching.siriDirectionCode("outbound"))
        assertEquals("R", DirectionMatching.siriDirectionCode(" Inbound "))
        assertEquals("", DirectionMatching.siriDirectionCode(null))
    }

    @Test
    fun paletteOverridesHeuristicColors() {
        LinePalette.reset()
        assertEquals("#8C368C", LineColors.backgroundHex("T2"), "sans palette : charte historique")
        val index = HttpClientProvider.json.decodeFromString(
            TimetableIndex.serializer(),
            """{"format":1,"validFrom":"2026-09-15","validTo":"2026-10-01","lines":[
                {"line":"T2","key":"T2","mode":"tram","color":"#6BA230","textColor":"#FFFFFF","directions":[]},
                {"line":"TS","key":"TS","mode":"tram","color":"#FFFFFF","textColor":"#CFB254","directions":[]}]}"""
        )
        var persisted: String? = null
        LinePalette.onChange = { persisted = it }
        val before = LinePalette.version.value
        LinePalette.apply(index)
        assertEquals(before + 1, LinePalette.version.value)
        assertEquals("#6BA230", LineColors.backgroundHex("t2"))
        assertEquals("#FFFFFF", LineColors.textHex("T2"))
        assertEquals("#6BA230", LineColors.routeStrokeHex("T2"))
        assertTrue(LineColors.needsBorder("TS"), "fond blanc : bordure")
        assertFalse(LineColors.needsBorder("T2"))
        assertEquals("#8C368C", LineColors.backgroundHex("T9"), "ligne absente de la palette : charte historique")

        LinePalette.apply(index)
        assertEquals(before + 1, LinePalette.version.value, "palette inchangée : pas de nouvelle version")

        val encoded = persisted
        LinePalette.reset()
        assertEquals("#8C368C", LineColors.backgroundHex("T2"))
        LinePalette.restore(encoded)
        assertEquals("#6BA230", LineColors.backgroundHex("T2"), "palette restaurée depuis la persistance")
        LinePalette.onChange = null
        LinePalette.reset()
    }

    @Test
    fun stopFocusFiltersLineAndDirection() {
        fun vehicle(line: String, direction: String) = Vehicle(
            id = "v-$line-$direction", latitude = 45.0, longitude = 4.8, bearing = 0.0, lineRef = "",
            lineName = line, vehicleType = VehicleType.BUS, destination = "", direction = direction, delay = 0
        )
        val focus = StopLineFocus("C3", "A", "Vaulx-en-Velin", "Bellecour", 45.0, 4.8)
        assertTrue(focus.matches(vehicle("C3", "A")))
        assertTrue(focus.matches(vehicle("c3", "")), "sens inconnu : on garde le véhicule")
        assertFalse(focus.matches(vehicle("C3", "R")))
        assertFalse(focus.matches(vehicle("C4", "A")))
        val lineOnly = focus.copy(direction = null)
        assertTrue(lineOnly.matches(vehicle("C3", "R")))
    }

    @Test
    fun staleWhenTheDayIsAfterTheLastCoveredOne() {
        val index = TimetableIndex(validFrom = "2026-09-15", validTo = "2026-12-01")
        assertFalse(index.isStaleOn("2026-12-01"))
        assertTrue(index.isStaleOn("2026-12-02"))
        assertTrue(com.alertetcl.shared.models.TimetableTexts.staleNotice("1er décembre").startsWith("Ces horaires ne sont plus à jour"))
    }

    @Test
    fun showOnMapOnlyForModesTrackedLive() {
        assertEquals(null, TransportMode.detectFromLine("A").showOnMapLabel)
        assertEquals(null, TransportMode.detectFromLine("F1").showOnMapLabel)
        assertEquals("Voir ces trams sur la carte", TransportMode.detectFromLine("T1").showOnMapLabel)
        assertEquals("Voir ces bus sur la carte", TransportMode.detectFromLine("C12").showOnMapLabel)
        assertEquals("Voir ces bus sur la carte", TransportMode.detectFromLine("27").showOnMapLabel)
    }

    @Test
    fun livePassagesKeepOnlyTheLineAndDirectionOfTheTimetable() {
        fun passage(line: String, direction: String, time: String, type: String = "E") =
            com.alertetcl.shared.models.Passage(11518, line, direction, "5 min", "2026-09-15 $time", type)
        val termini = mapOf("C12|A" to "Hôpital Feyzin Vénissieux", "C12|R" to "Gorge de Loup")
        val passages = listOf(
            passage("C12", "Gorge de Loup", "21:50:00"),
            passage("C12", "Hôp. Feyzin Vénissieux", "21:55:00"),
            passage("C25", "Saint-Genis 2", "21:52:00"),
            passage("C12", "Hôp. Feyzin Vénissieux", "21:55:00"),
            passage("C12", "Hôp. Feyzin Vénissieux", "22:20:00", "T"),
        )
        val next = com.alertetcl.shared.models.TimetableLive.nextPassages(passages, "C12", "A", termini)
        assertEquals(listOf("2026-09-15 21:55:00", "2026-09-15 22:20:00"), next.map { it.heurepassage })
        // Ligne sans terminus connus : on garde ses passages sans vérifier le sens.
        assertEquals(1, com.alertetcl.shared.models.TimetableLive.nextPassages(passages, "C25", "A", termini).size)
    }

    @Test
    fun focusBannerTextsDependOnTheOrigin() {
        val fromStop = com.alertetcl.shared.models.StopLineFocus("C12", "A", "Hôp. Feyzin", "Bellecour", 45.75, 4.83)
        assertEquals("Vers Hôp. Feyzin", fromStop.bannerTitle)
        assertEquals("2 véhicules affichés, depuis l'arrêt Bellecour", fromStop.bannerSubtitle(2))
        val fromVehicle = com.alertetcl.shared.models.StopLineFocus("C12", null, "Hôp. Feyzin", "", 45.75, 4.83)
        assertEquals("Ligne C12", fromVehicle.bannerTitle)
        assertEquals("Aucun véhicule en circulation pour l'instant", fromVehicle.bannerSubtitle(0))
        assertTrue(fromVehicle.matches("C12", "R"))
        assertEquals(5.0, com.alertetcl.shared.design.MapStyle.routeWidth("A"))
        assertEquals(3.0, com.alertetcl.shared.design.MapStyle.routeWidth("27"))
    }
}
