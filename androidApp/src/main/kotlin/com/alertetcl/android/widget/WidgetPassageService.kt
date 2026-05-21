package com.alertetcl.android.widget

import android.content.Context
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.services.TransitStopService
import com.alertetcl.shared.util.parsePassageEpoch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Fetches and filters passages for a specific stop + line + direction,
 * reusing the shared KMP [TransitStopService] (no duplicate HTTP client).
 * Caches the result so [WidgetPassageCache] can serve as fallback during Doze.
 */
internal object WidgetPassageService {

    private val displayFormat = SimpleDateFormat("HH:mm", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("Europe/Paris")
    }

    suspend fun fetchPassages(context: Context, stopId: Int, line: String, directionName: String): List<WidgetPassage> {
        val result = TransitStopService.shared
            .fetchPassagesForStop(stopId)
            .let { filterAndMap(it, line, directionName) }
        WidgetPassageCache.store(context, stopId, line, directionName, result)
        return result
    }

    private fun filterAndMap(
        passages: List<Passage>,
        line: String,
        directionName: String,
    ): List<WidgetPassage> {
        val nowMs     = System.currentTimeMillis()
        val normLine  = line.uppercase().trim()
        val normDir   = directionName.lowercase().trim()
        val dirPrefix = normDir.take(8)

        return passages
            .filter { p ->
                val matchLine = p.ligne.uppercase().trim() == normLine
                val pDir      = p.direction.lowercase().trim()
                val matchDir  = pDir.contains(dirPrefix) || normDir.contains(pDir.take(8))
                if (!matchLine || !matchDir) return@filter false
                val epochMs = parsePassageEpoch(p.heurepassage)?.times(1000L)
                    ?: return@filter true
                epochMs >= nowMs && (epochMs - nowMs) <= 120 * 60_000L
            }
            .sortedBy { parsePassageEpoch(it.heurepassage) ?: Long.MAX_VALUE }
            .take(6)
            .map { p ->
                val displayTime = parsePassageEpoch(p.heurepassage)
                    ?.let { displayFormat.format(Date(it * 1000L)) }
                    ?: "--:--"
                WidgetPassage(delay = p.delaipassage, time = displayTime, isRealTime = p.isRealTime)
            }
    }
}
