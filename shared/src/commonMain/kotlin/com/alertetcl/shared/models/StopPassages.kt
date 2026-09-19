package com.alertetcl.shared.models

/**
 * Un sens d'une ligne à un arrêt : son terminus et ses prochains passages, du plus proche au plus
 * lointain. Une rame qui s'arrête avant le terminus (dernier métro vers Debourg) reste dans le sens
 * de son quai ; [shortDestination] la signale. Un sens que le quai dessert mais sans passage annoncé
 * (la nuit, une ligne peu fréquente) est un groupe sans passage : la fiche horaire prend le relais.
 */
data class PassageGroup(
    val line: String,
    /** « A » ou « R » quand le sens est connu (quai à sens unique, ou destination reconnue), sinon null. */
    val directionCode: String?,
    /** Terminus du sens, ou la destination brute quand le sens est inconnu. */
    val terminus: String,
    /** Quai (identifiant GeoServer) du premier passage, ou celui dont la desserte annonce ce sens. */
    val stopId: Int?,
    val passages: List<Passage>
) {
    /** Clé stable pour les caches par sens (fiches horaires, bus en approche). */
    val key: String get() = "$line|${directionCode ?: DirectionMatching.normalize(terminus)}"

    /** Destination d'un passage qui ne va pas jusqu'au terminus (« Debourg »), sinon null. */
    fun shortDestination(passage: Passage): String? =
        if (DirectionMatching.namesMatch(passage.direction, terminus)) null else passage.direction
}

/** Regroupement des prochains passages d'un arrêt par ligne et par sens réel. */
object StopPassages {
    private val DIRECTION_CODES = setOf("A", "R")

    /**
     * Sens (« A » / « R ») que sert un quai pour une ligne, d'après sa desserte (« B:A,C12:R ») ;
     * null si le quai sert les deux sens ou ne connaît pas la ligne.
     */
    fun directionOfStop(desserte: String, line: String): String? =
        desserte.split(",")
            .mapNotNull { entry ->
                val parts = entry.split(":")
                if (parts.size >= 2 && parts[0].trim() == line) parts[1].trim() else null
            }
            .distinct()
            .singleOrNull()

    /**
     * Groupes ordonnés (mode, ligne, sens). Le sens vient d'abord du quai du passage
     * ([dessertes] : id de quai → desserte), sinon de la destination rapprochée des terminus.
     * Les sens que les quais desservent sans passage annoncé sont ajoutés vides, dès que leur
     * terminus est connu ([termini]) : l'arrêt reste lisible à toute heure.
     */
    fun group(passages: List<Passage>, dessertes: Map<Int, String>, termini: Map<String, String>): List<PassageGroup> {
        data class Slot(val line: String, val code: String?, val terminus: String, val stopId: Int, val passages: MutableList<Passage>)
        val slots = LinkedHashMap<String, Slot>()
        for (p in passages) {
            val code = dessertes[p.stopId]?.let { directionOfStop(it, p.ligne) }
                ?: DirectionMatching.resolveDirection(p.ligne, p.direction, termini)
            val terminus = code?.let { termini["${p.ligne}|$it"] } ?: p.direction
            val key = "${p.ligne}|${code ?: DirectionMatching.normalize(p.direction)}"
            slots.getOrPut(key) { Slot(p.ligne, code, terminus, p.stopId, mutableListOf()) }.passages.add(p)
        }
        for ((stopId, desserte) in dessertes) {
            for (entry in desserte.split(",")) {
                val parts = entry.split(":")
                if (parts.size < 2) continue
                val line = parts[0].trim()
                val code = parts[1].trim()
                if (line.isEmpty() || !TransitStop.isDisplayedLine(line) || code !in DIRECTION_CODES) continue
                val terminus = termini["$line|$code"] ?: continue
                slots.getOrPut("$line|$code") { Slot(line, code, terminus, stopId, mutableListOf()) }
            }
        }
        return slots.values
            .map { PassageGroup(it.line, it.code, it.terminus, it.stopId, it.passages.sortedBy { p -> p.heurepassage }) }
            .sortedWith(
                compareBy<PassageGroup> { TransportMode.detectFromLine(it.line).sortOrder }
                    .thenBy { it.line }.thenBy { it.directionCode ?: "~" }.thenBy { it.terminus }
            )
    }
}
