package com.alertetcl.android.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.favStore by preferencesDataStore(name = "favorites")

/**
 * Stockage des préférences utilisateur (lignes favorites, arrêts widget).
 * Toutes les valeurs sont sérialisées en CSV dans des clés string.
 */
class FavoritesStore(private val context: Context) {

    val favoriteLines: Flow<Set<String>> =
        context.favStore.data.map { p -> parse(p[KEY_FAV_LINES]) }

    val widgetStops: Flow<List<Int>> =
        context.favStore.data.map { p ->
            parse(p[KEY_WIDGET_STOPS]).mapNotNull { it.toIntOrNull() }
        }

    val premiumActive: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_PREMIUM] == "1" }

    val onboardingDone: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_ONBOARDING] == "1" }

    suspend fun toggleFavoriteLine(line: String) {
        context.favStore.edit { p ->
            val cur = parse(p[KEY_FAV_LINES]).toMutableSet()
            if (!cur.add(line)) cur.remove(line)
            p[KEY_FAV_LINES] = cur.joinToString(",")
        }
    }

    suspend fun addWidgetStop(stopId: Int) {
        context.favStore.edit { p ->
            val cur = parse(p[KEY_WIDGET_STOPS]).mapNotNull { it.toIntOrNull() }.toMutableSet()
            cur.add(stopId)
            p[KEY_WIDGET_STOPS] = cur.joinToString(",")
        }
    }

    suspend fun removeWidgetStop(stopId: Int) {
        context.favStore.edit { p ->
            val cur = parse(p[KEY_WIDGET_STOPS]).mapNotNull { it.toIntOrNull() }.toMutableSet()
            cur.remove(stopId)
            p[KEY_WIDGET_STOPS] = cur.joinToString(",")
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

    companion object {
        private val KEY_FAV_LINES    = stringPreferencesKey("fav_lines")
        private val KEY_WIDGET_STOPS = stringPreferencesKey("widget_stops")
        private val KEY_PREMIUM      = stringPreferencesKey("premium_active")
        private val KEY_ONBOARDING   = stringPreferencesKey("onboarding_done")
    }
}
