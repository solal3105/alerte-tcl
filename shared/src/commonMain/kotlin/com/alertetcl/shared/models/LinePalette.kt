package com.alertetcl.shared.models

import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlin.concurrent.Volatile

/** Couleurs du pictogramme d'une ligne : fond et texte, au format `#RRGGBB`. */
@Serializable
data class LineColorPair(val backgroundHex: String, val textHex: String)

/**
 * Couleurs officielles des lignes (`route_color` / `route_text_color` du GTFS SYTRAL),
 * chargées avec l'index des fiches horaires et conservées par l'application hôte entre
 * deux lancements. Sans entrée pour une ligne, [LineColors] retombe sur ses heuristiques.
 */
object LinePalette {
    @Volatile private var colors: Map<String, LineColorPair> = emptyMap()

    private val _version = MutableStateFlow(0)
    /** Incrémenté à chaque changement : sert de clé aux caches d'images de la carte. */
    val version: StateFlow<Int> = _version.asStateFlow()

    /** Appelé après chaque changement avec la palette encodée, pour la persistance côté app. */
    @Volatile var onChange: ((String) -> Unit)? = null

    fun colorFor(line: String): LineColorPair? = colors[TimetableKeys.keyFor(line)]

    /** Remplace la palette par celle de l'index (sans effet si elle est vide ou inchangée). */
    fun apply(index: TimetableIndex) {
        val next = index.lines
            .filter { it.color.isNotEmpty() && it.textColor.isNotEmpty() }
            .associate { it.key to LineColorPair(it.color, it.textColor) }
        if (next.isEmpty() || next == colors) return
        colors = next
        _version.value = _version.value + 1
        onChange?.invoke(encode())
    }

    fun encode(): String = HttpClientProvider.json.encodeToString(colors)

    /** Recharge une palette précédemment encodée (au démarrage, avant tout accès réseau). */
    fun restore(encoded: String?) {
        if (encoded.isNullOrBlank()) return
        val decoded = try {
            HttpClientProvider.json.decodeFromString<Map<String, LineColorPair>>(encoded)
        } catch (e: Exception) {
            AppLogger.warn("Palette de lignes illisible : ${e.message}")
            return
        }
        if (decoded.isEmpty() || decoded == colors) return
        colors = decoded
        _version.value = _version.value + 1
    }

    /** Réservé aux tests : repart d'une palette vide. */
    internal fun reset() {
        colors = emptyMap()
        _version.value = _version.value + 1
    }
}
