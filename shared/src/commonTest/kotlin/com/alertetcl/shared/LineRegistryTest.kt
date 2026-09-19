package com.alertetcl.shared

import com.alertetcl.shared.models.LineRegistry
import com.alertetcl.shared.models.MapFilterTexts
import com.alertetcl.shared.models.TimetableIndex
import com.alertetcl.shared.models.TimetableLineSummary
import com.alertetcl.shared.models.TransportMode
import kotlin.test.Test
import kotlin.test.assertEquals

class LineRegistryTest {
    private val index = TimetableIndex(
        validFrom = "2026-09-16", validTo = "2026-12-12",
        lines = listOf(
            TimetableLineSummary(line = "A", key = "A", mode = "metro"),
            TimetableLineSummary(line = "T1", key = "T1", mode = "tram"),
            TimetableLineSummary(line = "TB11", key = "TB11", mode = "trambus"),
            TimetableLineSummary(line = "F1", key = "F1", mode = "funicular"),
            TimetableLineSummary(line = "C12", key = "C12", mode = "trolleybus"),
            TimetableLineSummary(line = "121", key = "121", mode = "bus"),
            TimetableLineSummary(line = "NAVI1", key = "NAVI1", mode = "ferry"),
        )
    )

    @Test
    fun theNetworkLinesComeFromTheTimetableIndexWithTheirMode() {
        LineRegistry.apply(index)
        val lines = LineRegistry.current
        assertEquals(listOf("MA", "T1", "TB11", "F1", "C12", "121", "NAVI1"), lines.map { it.ligneCom })
        assertEquals("A", lines[0].ligneCli)
        assertEquals(
            listOf(TransportMode.METRO, TransportMode.TRAMWAY, TransportMode.TRAMWAY, TransportMode.FUNICULAR,
                TransportMode.BUS_C, TransportMode.BUS, TransportMode.NAVIGONE),
            lines.map { it.mode }
        )
        assertEquals(TransportMode.BUS, TransportMode.detectFromLine("121"))
        assertEquals(TransportMode.METRO, TransportMode.detectFromLine("a"))
        // Une ligne absente de l'index : la règle sur le nom prend le relais.
        assertEquals(TransportMode.BUS_C, TransportMode.detectFromLine("C99"))
        assertEquals(TransportMode.BUS, TransportMode.detectFromLine("999"))
    }

    @Test
    fun aRenumberedLineLeavesTheSavedFilters() {
        assertEquals(setOf("121", "C12"), MapFilterTexts.keepKnownLines(setOf("21", "121", "C12"), index))
    }
}
