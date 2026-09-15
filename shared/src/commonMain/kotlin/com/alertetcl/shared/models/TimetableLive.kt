package com.alertetcl.shared.models

/**
 * Passages en direct à afficher en tête d'une fiche horaire : ceux de la même ligne dans le même
 * sens, dédoublonnés et triés, les plus proches d'abord. Si les terminus de la ligne sont inconnus,
 * le sens ne peut pas être vérifié et tous les passages de la ligne sont conservés.
 */
object TimetableLive {
    fun nextPassages(
        passages: List<Passage>,
        line: String,
        direction: String,
        termini: Map<String, String>,
        limit: Int = 3
    ): List<Passage> {
        val directionKnown = termini.containsKey("$line|A") || termini.containsKey("$line|R")
        return passages
            .filter { it.ligne.equals(line, ignoreCase = true) }
            .filter { !directionKnown || DirectionMatching.resolveDirection(line, it.direction, termini) == direction }
            .distinctBy { "${it.heurepassage}|${it.direction}" }
            .sortedBy { it.heurepassage }
            .take(limit)
    }
}
