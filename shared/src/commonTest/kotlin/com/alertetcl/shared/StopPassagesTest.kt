package com.alertetcl.shared

import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.models.StopPassages
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class StopPassagesTest {
    private val termini = mapOf("B|A" to "St-Genis-Laval Hôp. Sud", "B|R" to "Charpennes Charles Hernu")
    private val dessertes = mapOf(46028 to "B:A", 46029 to "B:R", 30472 to "B:A,B:R")

    private fun p(stop: Int, dest: String, time: String) = Passage(stop, "B", dest, "3 min", "2026-09-20 00:$time:00", "T")

    @Test
    fun unGroupeParQuaiMemeAvecDesDestinationsPartielles() {
        val groups = StopPassages.group(
            listOf(p(46028, "Debourg", "10"), p(46028, "St-Genis-Laval Hôp. Sud", "05"), p(46029, "Jean Macé", "07"), p(46029, "Charpennes Charles Hernu", "12")),
            dessertes, termini
        )
        assertEquals(listOf("St-Genis-Laval Hôp. Sud", "Charpennes Charles Hernu"), groups.map { it.terminus })
        assertEquals(listOf("A", "R"), groups.map { it.directionCode })
        assertEquals(listOf("05", "10"), groups[0].passages.map { it.heurepassage.substring(14, 16) })
        assertEquals("Debourg", groups[0].shortDestination(groups[0].passages[1]))
        assertNull(groups[0].shortDestination(groups[0].passages[0]))
    }

    @Test
    fun quaiADeuxSensRetombeSurLaDestination() {
        val groups = StopPassages.group(listOf(p(30472, "St-Genis-Laval Hop. Sud", "05"), p(30472, "Gare d'Oullins", "08")), dessertes, termini)
        assertEquals(listOf("A", null), groups.map { it.directionCode })
        assertEquals("Gare d'Oullins", groups[1].terminus)
    }

    @Test
    fun sensDuQuai() {
        assertEquals("A", StopPassages.directionOfStop("B:A,C12:R", "B"))
        assertNull(StopPassages.directionOfStop("B:A,B:R", "B"))
        assertNull(StopPassages.directionOfStop("C12:R", "B"))
    }
}
