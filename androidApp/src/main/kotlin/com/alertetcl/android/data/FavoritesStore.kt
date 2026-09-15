package com.alertetcl.android.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.LineSubscription
import com.alertetcl.shared.models.LineSubscriptions
import com.alertetcl.shared.models.TransportLine
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.favStore by preferencesDataStore(name = "favorites")

/**
 * Stockage des préférences utilisateur : lignes favorites (filtres de la carte et des fiches
 * horaires), abonnements aux notifications, filtres persistés, palette des lignes.
 * Toutes les valeurs sont sérialisées dans des clés string.
 */
class FavoritesStore(private val context: Context) {

    val favoriteLines: Flow<Set<String>> =
        context.favStore.data.map { p -> parse(p[KEY_FAV_LINES]) }

    /**
     * Abonnements aux notifications (JSON de [LineSubscriptions]), distincts des favoris.
     * Les anciennes préférences (favoris + sévérités par ligne) sont reprises une fois, à la lecture.
     */
    val lineSubscriptions: Flow<Map<String, LineSubscription>> =
        context.favStore.data.map { p ->
            val stored = p[KEY_LINE_SUBSCRIPTIONS]
            if (stored != null) LineSubscriptions.decode(stored)
            else LineSubscriptions.migrateFromFavorites(
                existing = emptyMap(),
                favoriteLines = parse(p[KEY_FAV_LINES]),
                severityPreferences = parseSeverityPrefs(p[KEY_SEVERITY_PREFS]),
                lines = TransportLine.allPredefinedLines
            )
        }

    val premiumActive: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_PREMIUM] == "1" }

    val onboardingDone: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_ONBOARDING] == "1" }

    val selectedLiveLines: Flow<Set<String>> =
        context.favStore.data.map { p -> parse(p[KEY_SELECTED_LIVE_LINES]) }

    /** Palette officielle des lignes (JSON encodé par LinePalette), réappliquée au démarrage. */
    val linePalette: Flow<String?> =
        context.favStore.data.map { p -> p[KEY_LINE_PALETTE] }

    suspend fun setLinePalette(encoded: String) {
        context.favStore.edit { p -> p[KEY_LINE_PALETTE] = encoded }
    }

    /** Tracés des lignes bus sur la carte live (false = masqués par défaut). */
    val showBusTraces: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_SHOW_BUS_TRACES] == "1" }

    /** Tracés des lignes tram sur la carte live (true = affichés par défaut). */
    val showTramTraces: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_SHOW_TRAM_TRACES] != "0" }

    /** Tracés des lignes métro/funiculaire sur la carte live (true = affichés par défaut). */
    val showMetroTraces: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_SHOW_METRO_TRACES] != "0" }

    /** Stations Vélo'v sur la carte live (false = masquées par défaut). */
    val showVelov: Flow<Boolean> =
        context.favStore.data.map { p -> p[KEY_SHOW_VELOV] == "1" }

    suspend fun setShowVelov(show: Boolean) {
        context.favStore.edit { p -> p[KEY_SHOW_VELOV] = if (show) "1" else "0" }
    }

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

    /** Applique une transformation aux abonnements (abonner, désabonner, changer les types). */
    suspend fun updateLineSubscriptions(transform: (Map<String, LineSubscription>) -> Map<String, LineSubscription>) {
        context.favStore.edit { p ->
            val current = p[KEY_LINE_SUBSCRIPTIONS]?.let { LineSubscriptions.decode(it) }
                ?: LineSubscriptions.migrateFromFavorites(
                    existing = emptyMap(),
                    favoriteLines = parse(p[KEY_FAV_LINES]),
                    severityPreferences = parseSeverityPrefs(p[KEY_SEVERITY_PREFS]),
                    lines = TransportLine.allPredefinedLines
                )
            p[KEY_LINE_SUBSCRIPTIONS] = LineSubscriptions.encode(transform(current))
            p.remove(KEY_SEVERITY_PREFS)
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

    companion object {
        private val KEY_FAV_LINES           = stringPreferencesKey("fav_lines")
        private val KEY_PREMIUM             = stringPreferencesKey("premium_active")
        private val KEY_ONBOARDING          = stringPreferencesKey("onboarding_done")
        private val KEY_SELECTED_LIVE_LINES = stringPreferencesKey("live_selected_lines")
        /** Ancien format (sévérités par ligne favorite), lu uniquement pour la reprise. */
        private val KEY_SEVERITY_PREFS      = stringPreferencesKey("line_severity_prefs")
        private val KEY_LINE_SUBSCRIPTIONS  = stringPreferencesKey("line_subscriptions")
        private val KEY_SHOW_BUS_TRACES     = stringPreferencesKey("show_bus_traces")
        private val KEY_SHOW_TRAM_TRACES    = stringPreferencesKey("show_tram_traces")
        private val KEY_SHOW_METRO_TRACES   = stringPreferencesKey("show_metro_traces")
        private val KEY_SHOW_VELOV          = stringPreferencesKey("show_velov")
        private val KEY_LINE_PALETTE        = stringPreferencesKey("line_palette")
    }
}
