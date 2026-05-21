package com.alertetcl.android.widget

import android.content.Context
import androidx.compose.ui.graphics.Color
import com.alertetcl.shared.services.BusLineService
import com.alertetcl.shared.services.TransitLineService

// ── Passage data ──────────────────────────────────────────────────────────────

data class WidgetPassage(
    val delay: String,
    val time: String,
    val isRealTime: Boolean,
) {
    val delayMinutes: Int?
        get() = delay
            .lowercase()
            .replace(" min", "")
            .replace("min", "")
            .trim()
            .toIntOrNull()

    val smartDelay: String
        get() = delayMinutes?.let { if (it == 0) "À l'approche" else "$it min" } ?: time

    val compactDelay: String
        get() = delayMinutes?.let { if (it == 0) "~0'" else "$it'" } ?: time

    fun urgencyColor(fallback: Color): Color {
        // TCL brand colors like white (#FFFFFF for generic buses), yellow (#FFCC00 TB),
        // light orange (#F99D1D Metro C) and light green (#8BC752 Funiculaire) are
        // illegible as text on the widget's light background. Use near-black instead.
        val safeFallback = if (fallback.isReadableOnLight()) fallback else Color(0xFF1A1A1A)
        return when (val m = delayMinutes) {
            null -> safeFallback
            else -> when {
                m <= 2 -> Color(0xFFD32F2F)
                m <= 5 -> Color(0xFFE65100)
                else   -> safeFallback
            }
        }
    }
}

// ── Per-widget config ─────────────────────────────────────────────────────────

data class WidgetConfig(
    val stopId: Int,
    val stopName: String,
    val lineName: String,
    val direction: String,
    val destinationName: String = "",
) {
    val directionDisplay: String
        get() = destinationName.ifBlank { "—" }
}

// ── Error states ──────────────────────────────────────────────────────────────

enum class WidgetError { NO_PASSAGES, NETWORK_ERROR }

// ── Per-widget config storage (SharedPreferences keyed by appWidgetId) ─────────

internal object WidgetConfigStore {
    private const val PREFS_NAME = "widget_configs"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(context: Context, appWidgetId: Int, config: WidgetConfig) {
        prefs(context).edit()
            .putInt("stop_id_$appWidgetId",           config.stopId)
            .putString("stop_name_$appWidgetId",       config.stopName)
            .putString("line_name_$appWidgetId",       config.lineName)
            .putString("direction_$appWidgetId",       config.direction)
            .putString("dest_name_$appWidgetId",       config.destinationName)
            .apply()
    }

    fun load(context: Context, appWidgetId: Int): WidgetConfig? {
        val p = prefs(context)
        val stopId = p.getInt("stop_id_$appWidgetId", 0)
        if (stopId == 0) return null
        val direction = p.getString("direction_$appWidgetId", "").orEmpty()
        val destName  = p.getString("dest_name_$appWidgetId", "").orEmpty()
        return WidgetConfig(
            stopId          = stopId,
            stopName        = p.getString("stop_name_$appWidgetId", "").orEmpty(),
            lineName        = p.getString("line_name_$appWidgetId", "").orEmpty(),
            direction       = direction,
            // Fallback to direction for configs saved before destinationName was persisted
            destinationName = destName.ifBlank { direction },
        )
    }

    fun remove(context: Context, appWidgetId: Int) {
        prefs(context).edit()
            .remove("stop_id_$appWidgetId")
            .remove("stop_name_$appWidgetId")
            .remove("line_name_$appWidgetId")
            .remove("direction_$appWidgetId")
            .remove("dest_name_$appWidgetId")
            .apply()
    }
}

// ── Passage cache (fallback quand le réseau est indisponible en Doze) ────────

internal object WidgetPassageCache {
    private const val PREFS_NAME = "widget_passage_cache"
    private const val MAX_AGE_MS = 4 * 3600 * 1000L // 4 heures

    private fun key(stopId: Int, line: String, directionName: String) =
        "cache.$stopId.${line.uppercase()}.${directionName.lowercase()}"

    fun store(context: Context, stopId: Int, line: String, directionName: String, passages: List<WidgetPassage>) {
        val arr = org.json.JSONArray()
        passages.forEach { p ->
            arr.put(
                org.json.JSONObject()
                    .put("delay", p.delay)
                    .put("time", p.time)
                    .put("realTime", p.isRealTime)
            )
        }
        val k = key(stopId, line, directionName)
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(k, arr.toString())
            .putLong("$k.ts", System.currentTimeMillis())
            .apply()
    }

    fun load(context: Context, stopId: Int, line: String, directionName: String): List<WidgetPassage>? {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val k = key(stopId, line, directionName)
        val ts = prefs.getLong("$k.ts", 0L)
        if (System.currentTimeMillis() - ts > MAX_AGE_MS) return null
        val json = prefs.getString(k, null) ?: return null
        return runCatching {
            val arr = org.json.JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                WidgetPassage(
                    delay      = obj.getString("delay"),
                    time       = obj.getString("time"),
                    isRealTime = obj.getBoolean("realTime"),
                )
            }
        }.getOrNull()
    }
}

// ── Display config resolution ───────────────────────────────────────────────────

/**
 * Resolves [WidgetConfig.destinationName] for filtering and display.
 * Looks up the human-readable terminus from the combined bus+transit termini map
 * using the stored direction code ("A"/"R") as key, then falls back to the
 * already-stored [destinationName] if the fetch fails or returns nothing.
 */
internal suspend fun WidgetConfig.withResolvedDestination(): WidgetConfig {
    val terminus = runCatching {
        val bus     = BusLineService.shared.fetchLineTermini()
        val transit = TransitLineService.shared.fetchLineTermini()
        (bus + transit)["$lineName|$direction"].orEmpty()
    }.getOrDefault("")
    return copy(destinationName = terminus.ifBlank { destinationName })
}

// ── Contrast helpers ──────────────────────────────────────────────────────────

/**
 * True if this color has at least 3:1 contrast ratio on Color(0xFFF5F5F5),
 * the widget's light background. Uses the WCAG 2.1 relative luminance formula.
 * Ratio ≥ 3:1 is the minimum for large/bold text per WCAG AA.
 */
private fun Color.isReadableOnLight(): Boolean {
    @Suppress("MagicNumber")
    fun linearize(c: Float) = if (c <= 0.04045f) c / 12.92f
                              else Math.pow(((c + 0.055f) / 1.055f).toDouble(), 2.4).toFloat()
    val l   = 0.2126f * linearize(red) + 0.7152f * linearize(green) + 0.0722f * linearize(blue)
    val bgL = 0.9133f // luminance of Color(0xFFF5F5F5)
    return (bgL + 0.05f) / (l + 0.05f) >= 3f
}
