package com.alertetcl.android.widget

import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.services.TransitStopService
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Fetches and filters passages for a specific stop + line + direction,
 * reusing the shared KMP [TransitStopService] (no duplicate HTTP client).
 */
internal object WidgetPassageService {

    private val apiFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("Europe/Paris")
    }

    private val displayFormat = SimpleDateFormat("HH:mm", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("Europe/Paris")
    }

    suspend fun fetchPassages(stopId: Int, line: String, direction: String): List<WidgetPassage> =
        TransitStopService.shared
            .fetchPassagesForStop(stopId)
            .let { filterAndMap(it, line, direction) }

    private fun filterAndMap(
        passages: List<Passage>,
        line: String,
        direction: String,
    ): List<WidgetPassage> {
        val now       = Date()
        val normLine  = line.uppercase().trim()
        val normDir   = direction.lowercase().trim()
        val dirPrefix = normDir.take(8)

        return passages
            .filter { p ->
                val matchLine = p.ligne.uppercase().trim() == normLine
                val pDir      = p.direction.lowercase().trim()
                val matchDir  = pDir.contains(dirPrefix) || normDir.contains(pDir.take(8))
                if (!matchLine || !matchDir) return@filter false
                val date = runCatching { apiFormat.parse(p.heurepassage) }.getOrNull()
                    ?: return@filter true
                date >= now && (date.time - now.time) <= 90 * 60_000L
            }
            .sortedBy {
                runCatching { apiFormat.parse(it.heurepassage)?.time }.getOrElse { Long.MAX_VALUE }
            }
            .take(6)
            .map { p ->
                val displayTime = runCatching {
                    apiFormat.parse(p.heurepassage)?.let { displayFormat.format(it) }
                }.getOrNull() ?: "--:--"
                WidgetPassage(delay = p.delaipassage, time = displayTime, isRealTime = p.isRealTime)
            }
    }
}
