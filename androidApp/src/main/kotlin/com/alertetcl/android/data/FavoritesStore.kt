package com.alertetcl.android.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.alertetcl.shared.models.AlertSeverity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.favStore by preferencesDataStore(name = "favorites")

data class WidgetSelection(
    /** Stable key: "$stopId-$lineName-$directionCode" */
    val id: String,
    val stopId: Int,
    val stopName: String,
    val lineName: String,
    /** Direction API code: "A" or "R" */
    val direction: String,
    /** Human-readable terminus name for display */
    val destinationName: String = "",
)

/**
 * Stockage des préférences utilisateur (lignes favorites, sélections widget).
 * Toutes les valeurs sont sérialisées dans des clés string.
 */
class FavoritesStore(private val context: Context) {

    val favoriteLines: Flow<Set<String>> =
        context.favStore.data.map { p -> parse(p[KEY_FAV_LINES]) }

    val lineSeverityPreferences: Flow<Map<String, Set<AlertSeverity>>> =
        context.favStore.data.map { p -> parseSeverityPrefs(p[KEY_SEVERITY_PREFS]) }

    val widgetSelections: Flow<List<WidgetSelection>> =
        context.favStore.data.map { p -> deserializeSelections(p[KEY_WIDGET_SELECTIONS]) }

    /** Backward-compat: unique stop IDs derived from widgetSelections. */
    val widgetStops: Flow<List<Int>> =
        context.favStore.data.map { p ->
            deserializeSelections(p[KEY_WIDGET_SELECTIONS]).map { it.stopId }.distinct()
        }

    val premiumActive: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_PREMIUM] == "1" }

    val onboardingDone: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_ONBOARDING] == "1" }

    val selectedLiveLines: Flow<Set<String>> =
        context.favStore.data.map { p -> parse(p[KEY_SELECTED_LIVE_LINES]) }

    /** Tracés des lignes bus sur la carte live (false = masqués par défaut). */
    val showBusTraces: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_SHOW_BUS_TRACES] == "1" }

    /** Tracés des lignes tram sur la carte live (false = masqués par défaut). */
    val showTramTraces: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_SHOW_TRAM_TRACES] == "1" }

    /** Tracés des lignes métro/funiculaire sur la carte live (false = masqués par défaut). */
    val showMetroTraces: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_SHOW_METRO_TRACES] == "1" }

    suspend fun setShowBusTraces(show: Boolean) {
        context.favStore.edit { p -> p[KEY_SHOW_BUS_TRACES] = if (show) "1" else "0" }
    }

    suspend fun setShowTramTraces(show: Boolean) {
        context.favStore.edit { p -> p[KEY_SHOW_TRAM_TRACES] = if (show) "1" else "0" }
    }

    suspend fun setShowMetroTraces(show: Boolean) {
        context.favStore.edit { p -> p[KEY_SHOW_METRO_TRACES] = if (show) "1" else "0" }
    }

    suspend fun setSelectedLiveLines(lines: Set<String>) {
        context.favStore.edit { p ->
            p[KEY_SELECTED_LIVE_LINES] = lines.joinToString(",")
        }
    }

    suspend fun toggleFavoriteLine(line: String) {
        context.favStore.edit { p ->
            val cur = parse(p[KEY_FAV_LINES]).toMutableSet()
            if (!cur.add(line)) cur.remove(line)
            p[KEY_FAV_LINES] = cur.joinToString(",")
        }
    }

    suspend fun setLineSeverityPreferences(lineId: String, severities: Set<AlertSeverity>) {
        context.favStore.edit { p ->
            val current = parseSeverityPrefs(p[KEY_SEVERITY_PREFS]).toMutableMap()
            if (severities.isEmpty()) current.remove(lineId) else current[lineId] = severities
            p[KEY_SEVERITY_PREFS] = serializeSeverityPrefs(current)
        }
    }

    suspend fun addWidgetSelection(sel: WidgetSelection) {
        context.favStore.edit { p ->
            val cur = deserializeSelections(p[KEY_WIDGET_SELECTIONS]).toMutableList()
            cur.removeAll { it.id == sel.id }
            cur.add(0, sel)
            if (cur.size > 30) cur.subList(30, cur.size).clear()
            p[KEY_WIDGET_SELECTIONS] = serializeSelections(cur)
        }
    }

    suspend fun removeWidgetSelection(id: String) {
        context.favStore.edit { p ->
            val cur = deserializeSelections(p[KEY_WIDGET_SELECTIONS]).toMutableList()
            cur.removeAll { it.id == id }
            p[KEY_WIDGET_SELECTIONS] = serializeSelections(cur)
        }
    }

    suspend fun removeWidgetSelectionsForStop(stopId: Int) {
        context.favStore.edit { p ->
            val cur = deserializeSelections(p[KEY_WIDGET_SELECTIONS]).toMutableList()
            cur.removeAll { it.stopId == stopId }
            p[KEY_WIDGET_SELECTIONS] = serializeSelections(cur)
        }
    }

    suspend fun setPremium(active: Boolean) {
        context.favStore.edit { p -> p[KEY_PREMIUM] = if (active) "1" else "0" }
    }

    suspend fun setOnboardingDone() {
        context.favStore.edit { p -> p[KEY_ONBOARDING] = "1" }
    }

    private fun parse(s: String?): Set<String> =
        s.orEmpty().split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()

    private fun parseSeverityPrefs(raw: String?): Map<String, Set<AlertSeverity>> {
        if (raw.isNullOrBlank()) return emptyMap()
        return raw.split("|").mapNotNull { part ->
            val idx = part.indexOf('=')
            if (idx < 0) return@mapNotNull null
            val lineId = part.substring(0, idx)
            val severities = part.substring(idx + 1).split("+")
                .mapNotNull { s -> AlertSeverity.values().find { it.name == s } }
                .toSet()
            if (lineId.isBlank() || severities.isEmpty()) return@mapNotNull null
            lineId to severities
        }.toMap()
    }

    private fun serializeSeverityPrefs(prefs: Map<String, Set<AlertSeverity>>): String =
        prefs.entries.joinToString("|") { (lineId, sevs) ->
            "$lineId=${sevs.joinToString("+") { it.name }}"
        }

    private fun serializeSelections(list: List<WidgetSelection>): String =
        list.joinToString("\n") { "${it.stopId}$SEP${it.stopName}$SEP${it.lineName}$SEP${it.direction}$SEP${it.destinationName}" }

    private fun deserializeSelections(raw: String?): List<WidgetSelection> =
        raw.orEmpty().lines().mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val parts = line.split(SEP, limit = 5)
            if (parts.size < 4) return@mapNotNull null
            val stopId = parts[0].toIntOrNull() ?: return@mapNotNull null
            val stopName = parts[1]; val lineName = parts[2]; val direction = parts[3]
            val destinationName = if (parts.size >= 5) parts[4] else ""
            WidgetSelection("$stopId-$lineName-$direction", stopId, stopName, lineName, direction, destinationName)
        }

    companion object {
        private const val SEP = "\u001F"
        private val KEY_FAV_LINES           = stringPreferencesKey("fav_lines")
        private val KEY_WIDGET_SELECTIONS   = stringPreferencesKey("widget_selections")
        private val KEY_PREMIUM             = stringPreferencesKey("premium_active")
        private val KEY_ONBOARDING          = stringPreferencesKey("onboarding_done")
        private val KEY_SELECTED_LIVE_LINES = stringPreferencesKey("live_selected_lines")
        private val KEY_SEVERITY_PREFS      = stringPreferencesKey("line_severity_prefs")
        private val KEY_SHOW_BUS_TRACES     = stringPreferencesKey("show_bus_traces")
        private val KEY_SHOW_TRAM_TRACES    = stringPreferencesKey("show_tram_traces")
        private val KEY_SHOW_METRO_TRACES   = stringPreferencesKey("show_metro_traces")
    }
}
