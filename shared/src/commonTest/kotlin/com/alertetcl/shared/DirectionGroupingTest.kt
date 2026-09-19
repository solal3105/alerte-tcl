package com.alertetcl.shared

import com.alertetcl.shared.models.DirectionMatching
import kotlin.test.Test
import kotlin.test.assertEquals

class DirectionGroupingTest {
    private val termini = mapOf("B|A" to "Charpennes Charles Hernu", "B|R" to "St-Genis-Laval Hôpital Lyon Sud")

    @Test
    fun deuxGraphiesDuMemeSensDonnentLeMemeNom() {
        assertEquals("Charpennes Charles Hernu", DirectionMatching.canonicalDestination("B", "Charpennes", termini))
        assertEquals("Charpennes Charles Hernu", DirectionMatching.canonicalDestination("B", "CHARPENNES CHARLES HERNU", termini))
        assertEquals("St-Genis-Laval Hôpital Lyon Sud", DirectionMatching.canonicalDestination("B", "Saint-Genis-Laval Hop. Lyon Sud", termini))
    }

    @Test
    fun destinationInconnueGardeeTelleQuelle() {
        assertEquals("Gare d'Oullins", DirectionMatching.canonicalDestination("B", "Gare d'Oullins", termini))
        assertEquals("Charpennes", DirectionMatching.canonicalDestination("B", "Charpennes", emptyMap()))
    }
}
