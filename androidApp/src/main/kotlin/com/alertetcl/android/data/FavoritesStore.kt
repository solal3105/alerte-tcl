package com.alertetcl.android.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.favStore by preferencesDataStore(name = "favorites")

data class WidgetSelection(
    /** Stable key: "$stopId-$lineName-$direction" */
    val id: String,
    val stopId: Int,
    val stopName: String,
    val lineName: String,
    val direction: String,
)

/**
 * Stockage des préférences utilisateur (lignes favorites, sélections widget).
 * Toutes les valeurs sont sérialisées dans des clés string.
 */
class FavoritesStore(private val context: Context) {

    val favoriteLines: Flow<Set<String>> =
        context.favStore.data.map { p -> parse(p[KEY_FAV_LINES]) }

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

    private fun serializeSelections(list: List<WidgetSelection>): String =
        list.joinToString("\n") { "${it.stopId}$SEP${it.stopName}$SEP${it.lineName}$SEP${it.direction}" }

    private fun deserializeSelections(raw: String?): List<WidgetSelection> =
        raw.orEmpty().lines().mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val parts = line.split(SEP, limit = 4)
            if (parts.size < 4) return@mapNotNull null
            val stopId = parts[0].toIntOrNull() ?: return@mapNotNull null
            val stopName = parts[1]; val lineName = parts[2]; val direction = parts[3]
            WidgetSelection("$stopId-$lineName-$direction", stopId, stopName, lineName, direction)
        }

    companion object {
        private const val SEP = "\u001F"
        private val KEY_FAV_LINES           = stringPreferencesKey("fav_lines")
        private val KEY_WIDGET_SELECTIONS   = stringPreferencesKey("widget_selections")
        private val KEY_PREMIUM             = stringPreferencesKey("premium_active")
        private val KEY_ONBOARDING          = stringPreferencesKey("onboarding_done")
        private val KEY_SELECTED_LIVE_LINES = stringPreferencesKey("live_selected_lines")
    }
}
