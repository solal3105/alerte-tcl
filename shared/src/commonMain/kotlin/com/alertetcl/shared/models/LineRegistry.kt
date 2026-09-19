package com.alertetcl.shared.models

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Lignes du réseau et leur mode, lues dans l'index des fiches horaires (régénéré chaque nuit à
 * partir du GTFS SYTRAL). Aucune liste embarquée : une renumérotation n'attend pas une mise à
 * jour de l'application. Vide tant que l'index n'a pas été chargé.
 */
object LineRegistry {
    private val _lines = MutableStateFlow<List<TransportLine>>(emptyList())
    val lines: StateFlow<List<TransportLine>> = _lines.asStateFlow()

    /** Variante sans flux, pour Swift. */
    val current: List<TransportLine> get() = _lines.value

    private var modesByName: Map<String, TransportMode> = emptyMap()

    /** Remplace les lignes par celles de l'index (sans effet si l'index n'en porte aucune). */
    fun apply(index: TimetableIndex) {
        val next = fromIndex(index)
        if (next.isEmpty()) return
        modesByName = buildMap { next.forEach { put(it.ligneCom.uppercase(), it.mode); put(it.ligneCli.uppercase(), it.mode) } }
        _lines.value = next
    }

    /** Mode d'une ligne connue de l'index, null sinon. */
    fun modeOf(line: String): TransportMode? = modesByName[line.uppercase()]

    private fun fromIndex(index: TimetableIndex): List<TransportLine> = index.lines.map { summary ->
        val name = summary.line
        val mode = when (summary.mode) {
            "metro" -> TransportMode.METRO
            "tram", "trambus" -> TransportMode.TRAMWAY
            "funicular" -> TransportMode.FUNICULAR
            "ferry" -> TransportMode.NAVIGONE
            else -> if (name.length >= 2 && name[0] == 'C' && name[1].isDigit()) TransportMode.BUS_C else TransportMode.BUS
        }
        // Les métros gardent leur code historique (« MA » pour la ligne A) : les abonnements y sont rattachés.
        if (mode == TransportMode.METRO) TransportLine.create("M$name", name, mode) else TransportLine.create(name, name, mode)
    }
}
