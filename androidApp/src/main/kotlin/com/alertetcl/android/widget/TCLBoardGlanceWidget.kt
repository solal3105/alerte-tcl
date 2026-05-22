package com.alertetcl.android.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.layout.wrapContentWidth
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.LineColors

// ── Board palette ─────────────────────────────────────────────────────────────

private val tclGold  = Color(0xFFE8C00A)
private val ledGreen = Color(0xFF33EB33)
private val ledAmber = Color(0xFFFF8F00)
private val boardBg  = Color(0xFF0A0A0A)

class TCLBoardGlanceWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Responsive(
        setOf(
            DpSize(72.dp, 72.dp),   // 1×1: nano
            DpSize(148.dp, 148.dp), // 2×2: small board
            DpSize(222.dp, 148.dp), // 3×2: medium board
        )
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val config = WidgetConfigStore.load(context, appWidgetId)

        if (config == null) {
            provideContent { BoardNotConfigured(context, appWidgetId) }
            return
        }

        val displayConfig = config.withResolvedDestination()

        val passages = runCatching {
            WidgetPassageService.fetchPassages(context, config.stopId, config.lineName, displayConfig.destinationName)
        }.getOrElse {
            // réseau KO (Doze, App Standby RARE…) : fallback sur le cache jusqu'à 4 h
            WidgetPassageCache.load(context, config.stopId, config.lineName, displayConfig.destinationName).orEmpty()
        }

        provideContent {
            val size = LocalSize.current
            when {
                size.height <= 72.dp && size.width <= 72.dp -> BoardNanoView(displayConfig, passages)
                size.width <= 148.dp                         -> BoardSmallView(displayConfig, passages)
                else                                         -> BoardMediumView(displayConfig, passages)
            }
        }
    }
}

class TCLBoardGlanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TCLBoardGlanceWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshScheduler.schedule(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        appWidgetIds.forEach { WidgetConfigStore.remove(context, it) }
    }
}

// ── Not configured ────────────────────────────────────────────────────────────

@Composable
private fun BoardNotConfigured(context: Context, widgetId: Int) {
    val clickAction = actionStartActivity(
        Intent(context, TCLBoardWidgetConfigActivity::class.java)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    )
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(boardBg))
            .clickable(clickAction),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "NON CONFIGURÉ",
            style = TextStyle(
                color = ColorProvider(ledAmber.copy(alpha = 0.70f)),
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            ),
        )
        Spacer(GlanceModifier.height(4.dp))
        Text(
            "Appuyer pour configurer",
            style = TextStyle(
                color = ColorProvider(ledGreen.copy(alpha = 0.45f)),
                fontSize = 8.sp,
                fontFamily = FontFamily.Monospace,
            ),
        )
    }
}

// ── Nano board (1×1) ──────────────────────────────────────────────────────────

@Composable
private fun BoardNanoView(config: WidgetConfig, passages: List<WidgetPassage>) {
    val next = passages.firstOrNull()
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(boardBg))
            .padding(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        BoardLineBadge(config.lineName, size = 24.dp)
        Spacer(GlanceModifier.height(4.dp))
        Text(
            next?.compactDelay ?: "—",
            style = TextStyle(
                color = ColorProvider(if (next != null) ledGreen else ledGreen.copy(alpha = 0.25f)),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            ),
            maxLines = 1,
        )
        if (passages.size > 1) {
            Text(
                passages[1].compactDelay,
                style = TextStyle(
                    color = ColorProvider(ledAmber.copy(alpha = 0.70f)),
                    fontSize = 10.sp,
                    fontFamily = FontFamily.Monospace,
                ),
                maxLines = 1,
            )
        }
    }
}

// ── Small board ───────────────────────────────────────────────────────────────

@Composable
private fun BoardSmallView(config: WidgetConfig, passages: List<WidgetPassage>) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(boardBg)),
    ) {
        // Gold header bar
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .background(ColorProvider(tclGold))
                .padding(horizontal = 10.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BoardLineBadge(config.lineName, size = 22.dp)
            Spacer(GlanceModifier.width(7.dp))
            Column {
                Text(
                    config.directionDisplay,
                    style = TextStyle(
                        color = ColorProvider(Color.Black),
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    maxLines = 1,
                )
                Text(
                    config.stopName,
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF1A1A1A)),
                        fontSize = 7.sp,
                    ),
                    maxLines = 1,
                )
            }
        }

        // LED screen
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Spacer(GlanceModifier.height(4.dp))
            BoardLedRow(label = "Prochain", passage = passages.getOrNull(0), color = ledGreen)
            BoardDivider()
            BoardLedRow(label = "Suivant ", passage = passages.getOrNull(1), color = ledAmber)
            Spacer(GlanceModifier.height(4.dp))
        }
    }
}

// ── Medium board ──────────────────────────────────────────────────────────────

@Composable
private fun BoardMediumView(config: WidgetConfig, passages: List<WidgetPassage>) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(boardBg)),
    ) {
        // Gold header bar
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .background(ColorProvider(tclGold))
                .padding(horizontal = 13.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BoardLineBadge(config.lineName, size = 28.dp)
            Spacer(GlanceModifier.width(9.dp))
            Column(modifier = GlanceModifier.fillMaxWidth()) {
                Text(
                    config.directionDisplay,
                    style = TextStyle(
                        color = ColorProvider(Color.Black),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    maxLines = 1,
                )
                Text(
                    "arrêt ${config.stopName}",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF1A1A1A)),
                        fontSize = 8.sp,
                    ),
                    maxLines = 1,
                )
            }
        }

        // LED screen — 3 rows
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Spacer(GlanceModifier.height(4.dp))
            // Row 1: next — scheduled time column + delay
            BoardMediumLedRow(
                scheduledTime = passages.getOrNull(0)?.takeIf {
                    it.delayMinutes != null
                }?.time,
                label = "Prochain",
                passage = passages.getOrNull(0),
                color = ledGreen,
            )
            BoardDivider()
            BoardMediumLedRow(
                scheduledTime = null,
                label = "Suivant ",
                passage = passages.getOrNull(1),
                color = ledAmber,
            )
            if (passages.size > 2) {
                BoardDivider()
                BoardMediumLedRow(
                    scheduledTime = null,
                    label = "Dans    ",
                    passage = passages.getOrNull(2),
                    color = ledAmber.copy(alpha = 0.55f),
                )
            }
            Spacer(GlanceModifier.height(4.dp))
        }
    }
}

// ── Board sub-components ──────────────────────────────────────────────────────

@Composable
private fun BoardLineBadge(lineName: String, size: androidx.compose.ui.unit.Dp) {
    val bgColor   = colorFromHex(LineColors.backgroundHex(lineName))
    val textColor = colorFromHex(LineColors.textHex(lineName))
    Box(
        modifier = GlanceModifier
            .size(size)
            .background(ColorProvider(bgColor))
            .cornerRadius(size / 2),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            lineName,
            style = TextStyle(
                color = ColorProvider(textColor),
                fontSize = (size.value * 0.36f).sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

@Composable
private fun BoardLedRow(
    label: String,
    passage: WidgetPassage?,
    color: Color,
) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(horizontal = 10.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = TextStyle(
                color = ColorProvider(color),
                fontSize = 9.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = FontFamily.Monospace,
            ),
        )
        Text(
            ": ",
            style = TextStyle(
                color = ColorProvider(color.copy(alpha = 0.60f)),
                fontSize = 9.sp,
                fontFamily = FontFamily.Monospace,
            ),
        )
        Text(
            passage?.smartDelay ?: "—",
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = ColorProvider(if (passage != null) color else color.copy(alpha = 0.25f)),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            ),
            maxLines = 1,
        )
    }
}

@Composable
private fun BoardMediumLedRow(
    scheduledTime: String?,
    label: String,
    passage: WidgetPassage?,
    color: Color,
) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Scheduled time column (green, like the real TCL board)
        Text(
            scheduledTime ?: "     ",
            style = TextStyle(
                color = ColorProvider(if (scheduledTime != null) ledGreen else Color.Transparent),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            ),
        )
        Spacer(GlanceModifier.width(6.dp))
        Text(
            label,
            style = TextStyle(
                color = ColorProvider(color),
                fontSize = 9.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = FontFamily.Monospace,
            ),
        )
        Text(
            ": ",
            style = TextStyle(
                color = ColorProvider(color.copy(alpha = 0.60f)),
                fontSize = 9.sp,
                fontFamily = FontFamily.Monospace,
            ),
        )
        Text(
            passage?.smartDelay ?: "—",
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = ColorProvider(if (passage != null) color else color.copy(alpha = 0.25f)),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            ),
            maxLines = 1,
        )
    }
}

@Composable
private fun BoardDivider() {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(1.dp)
            .background(ColorProvider(Color.White.copy(alpha = 0.07f))),
    ) {}
}
