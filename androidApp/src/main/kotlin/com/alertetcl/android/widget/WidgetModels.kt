package com.alertetcl.android.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.glance.GlanceId
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver

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

    fun urgencyColor(fallback: Color): Color = when (val m = delayMinutes) {
        null -> fallback
        else -> when {
            m <= 2 -> Color(0xFFE53935)
            m <= 5 -> Color(0xFFFF6D00)
            else   -> fallback
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

    private fun key(stopId: Int, line: String, direction: String) =
        "cache.$stopId.${line.uppercase()}.${direction.lowercase()}"

    fun store(context: Context, stopId: Int, line: String, direction: String, passages: List<WidgetPassage>) {
        val arr = org.json.JSONArray()
        passages.forEach { p ->
            arr.put(
                org.json.JSONObject()
                    .put("delay", p.delay)
                    .put("time", p.time)
                    .put("realTime", p.isRealTime)
            )
        }
        val k = key(stopId, line, direction)
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(k, arr.toString())
            .putLong("$k.ts", System.currentTimeMillis())
            .apply()
    }

    fun load(context: Context, stopId: Int, line: String, direction: String): List<WidgetPassage>? {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val k = key(stopId, line, direction)
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

// ── Helper: extract appWidgetId from an opaque GlanceId ──────────────────────

internal fun GlanceId.toAppWidgetId(
    context: Context,
    receiverClass: Class<out GlanceAppWidgetReceiver>,
): Int? = AppWidgetManager.getInstance(context)
    .getAppWidgetIds(ComponentName(context, receiverClass))
    .firstOrNull { wid -> GlanceAppWidgetManager(context).getGlanceIdBy(wid) == this }
