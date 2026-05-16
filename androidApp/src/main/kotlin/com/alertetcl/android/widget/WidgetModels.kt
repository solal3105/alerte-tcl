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
)

// ── Error states ──────────────────────────────────────────────────────────────

enum class WidgetError { NO_PASSAGES, NETWORK_ERROR }

// ── Per-widget config storage (SharedPreferences keyed by appWidgetId) ─────────

internal object WidgetConfigStore {
    private const val PREFS_NAME = "widget_configs"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(context: Context, appWidgetId: Int, config: WidgetConfig) {
        prefs(context).edit()
            .putInt("stop_id_$appWidgetId",     config.stopId)
            .putString("stop_name_$appWidgetId", config.stopName)
            .putString("line_name_$appWidgetId", config.lineName)
            .putString("direction_$appWidgetId", config.direction)
            .apply()
    }

    fun load(context: Context, appWidgetId: Int): WidgetConfig? {
        val p = prefs(context)
        val stopId = p.getInt("stop_id_$appWidgetId", 0)
        if (stopId == 0) return null
        return WidgetConfig(
            stopId    = stopId,
            stopName  = p.getString("stop_name_$appWidgetId", "").orEmpty(),
            lineName  = p.getString("line_name_$appWidgetId", "").orEmpty(),
            direction = p.getString("direction_$appWidgetId", "").orEmpty(),
        )
    }

    fun remove(context: Context, appWidgetId: Int) {
        prefs(context).edit()
            .remove("stop_id_$appWidgetId")
            .remove("stop_name_$appWidgetId")
            .remove("line_name_$appWidgetId")
            .remove("direction_$appWidgetId")
            .apply()
    }
}

// ── Helper: extract appWidgetId from an opaque GlanceId ──────────────────────

internal fun GlanceId.toAppWidgetId(
    context: Context,
    receiverClass: Class<out GlanceAppWidgetReceiver>,
): Int? = AppWidgetManager.getInstance(context)
    .getAppWidgetIds(ComponentName(context, receiverClass))
    .firstOrNull { wid -> GlanceAppWidgetManager(context).getGlanceIdBy(wid) == this }
