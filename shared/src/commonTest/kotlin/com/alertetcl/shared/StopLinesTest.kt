package com.alertetcl.shared

import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.util.DemoShowcase
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class StopLinesTest {
    @Test
    fun lignesScolairesJuniorDirectExcluesDesArrets() {
        val stop = DemoShowcase.mergedStop().stops[0].copy(desserte = "C12:A,JD125:R,jd7:A,C12:R,T1:A")
        assertEquals(listOf("C12", "T1"), stop.lines)
    }

    @Test
    fun regleDesLignesAffichees() {
        assertFalse(TransitStop.isDisplayedLine("JD125"))
        assertFalse(TransitStop.isDisplayedLine("jd7"))
        assertTrue(TransitStop.isDisplayedLine("J1"))
        assertTrue(TransitStop.isDisplayedLine("C12"))
    }
}
