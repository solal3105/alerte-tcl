package com.alertetcl.android.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.services.BusLineService
import com.alertetcl.shared.services.TransitLineService
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
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
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.layout.wrapContentWidth
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

class NextDeparturesGlanceWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Responsive(
        setOf(
            DpSize(110.dp, 110.dp), // small
            DpSize(220.dp, 110.dp), // medium
            DpSize(220.dp, 220.dp), // large
        )
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = id.toAppWidgetId(context, NextDeparturesGlanceWidgetReceiver::class.java)
        val config = appWidgetId?.let { WidgetConfigStore.load(context, it) }

        if (config == null) {
            val widId = appWidgetId ?: AppWidgetManager.INVALID_APPWIDGET_ID
            provideContent { NotConfiguredContent("", context, widId) }
            return
        }

        val terminusName = runCatching {
            val bus     = BusLineService.shared.fetchLineTermini()
            val transit = TransitLineService.shared.fetchLineTermini()
            (bus + transit)["${config.lineName}|${config.direction}"].orEmpty()
        }.getOrDefault("")
        val displayConfig = config.copy(destinationName = terminusName)

        val (passages, fetchError) = runCatching {
            WidgetPassageService.fetchPassages(context, config.stopId, config.lineName, config.direction) to null
        }.getOrElse {
            // réseau KO (Doze, App Standby RARE…) : fallback sur le cache jusqu'à 4 h
            val cached = WidgetPassageCache.load(context, config.stopId, config.lineName, config.direction)
            if (cached != null) cached to null
            else emptyList<WidgetPassage>() to WidgetError.NETWORK_ERROR
        }

        val effectiveError = fetchError
            ?: if (passages.isEmpty()) WidgetError.NO_PASSAGES else null

        provideContent { WidgetContent(displayConfig, passages, effectiveError) }
    }

    @Composable
    private fun WidgetContent(
        config: WidgetConfig,
        passages: List<WidgetPassage>,
        error: WidgetError?,
    ) {
        val size = LocalSize.current
        when {
            size.width < 180.dp  -> SmallContent(config, passages, error)
            size.height < 180.dp -> MediumContent(config, passages, error)
            else                 -> LargeContent(config, passages, error)
        }
    }
}

class NextDeparturesGlanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextDeparturesGlanceWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshScheduler.schedule(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        appWidgetIds.forEach { WidgetConfigStore.remove(context, it) }
    }
}

// ── Not-configured state ──────────────────────────────────────────────────────

@Composable
private fun NotConfiguredContent(lineName: String, context: Context, widgetId: Int) {
    val lineColor = if (lineName.isNotEmpty()) colorFromHex(LineColors.backgroundHex(lineName))
                   else Color(0xFF1565C0)
    val clickAction = actionStartActivity(
        Intent(context, WidgetConfigActivity::class.java)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    )
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(Color(0xFFF5F5F5)))
            .padding(16.dp)
            .clickable(clickAction),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (lineName.isNotEmpty()) {
            LineBadge(lineName, lineColor, colorFromHex(LineColors.textHex(lineName)), 12.sp)
            Spacer(GlanceModifier.height(8.dp))
        }
        Text(
            "Appuyer pour configurer",
            style = TextStyle(
                color = ColorProvider(Color(0xFF888888)),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
            ),
        )
    }
}

// ── Small layout ──────────────────────────────────────────────────────────────

@Composable
private fun SmallContent(
    config: WidgetConfig,
    passages: List<WidgetPassage>,
    error: WidgetError?,
) {
    val lineColor     = colorFromHex(LineColors.backgroundHex(config.lineName))
    val lineTextColor = colorFromHex(LineColors.textHex(config.lineName))

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(Color(0xFFF5F5F5))),
    ) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(start = 12.dp, end = 8.dp, top = 11.dp),
            verticalAlignment = Alignment.Top,
        ) {
            LineBadge(config.lineName, lineColor, lineTextColor, 11.sp)
            Spacer(GlanceModifier.width(6.dp))
            Text(
                "→ ${config.directionDisplay}",
                modifier = GlanceModifier.fillMaxWidth(),
                style = TextStyle(color = ColorProvider(Color(0xFF666666)), fontSize = 9.sp),
                maxLines = 2,
            )
        }

        Spacer(GlanceModifier.height(4.dp))

        if (error != null) {
            Box(
                modifier = GlanceModifier.fillMaxSize().padding(12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(errorLabel(error), style = errorTextStyle())
            }
        } else if (passages.isNotEmpty()) {
            val next = passages.first()
            Column(
                modifier = GlanceModifier.fillMaxWidth().padding(horizontal = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    next.compactDelay,
                    style = TextStyle(
                        color = ColorProvider(next.urgencyColor(lineColor)),
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    maxLines = 1,
                )
                if (passages.size > 1) {
                    val second = passages[1]
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "puis ",
                            style = TextStyle(color = ColorProvider(Color(0xFF888888)), fontSize = 10.sp),
                        )
                        Text(
                            second.compactDelay,
                            style = TextStyle(
                                color = ColorProvider(second.urgencyColor(Color(0xFF888888))),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                            ),
                        )
                    }
                }
            }

            Spacer(GlanceModifier.height(4.dp))

            Text(
                config.stopName,
                modifier = GlanceModifier.padding(start = 12.dp, bottom = 11.dp),
                style = TextStyle(
                    color = ColorProvider(Color(0xFF333333)),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                ),
                maxLines = 1,
            )
        }
    }
}

// ── Medium layout ─────────────────────────────────────────────────────────────

@Composable
private fun MediumContent(
    config: WidgetConfig,
    passages: List<WidgetPassage>,
    error: WidgetError?,
) {
    val lineColor     = colorFromHex(LineColors.backgroundHex(config.lineName))
    val lineTextColor = colorFromHex(LineColors.textHex(config.lineName))

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(Color(0xFFF5F5F5))),
    ) {
        WidgetHeader(config, lineColor, lineTextColor, passages.firstOrNull()?.isRealTime == true)

        if (error != null) {
            Box(
                modifier = GlanceModifier.fillMaxSize().padding(16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(errorLabel(error), style = errorTextStyle())
            }
        } else {
            val rows = passages.take(3)
            rows.forEachIndexed { i, passage ->
                PassageRow(passage, isFirst = i == 0, lineColor = lineColor)
                if (i < rows.lastIndex) WidgetDivider()
            }
        }
    }
}

// ── Large layout ──────────────────────────────────────────────────────────────

@Composable
private fun LargeContent(
    config: WidgetConfig,
    passages: List<WidgetPassage>,
    error: WidgetError?,
) {
    val lineColor     = colorFromHex(LineColors.backgroundHex(config.lineName))
    val lineTextColor = colorFromHex(LineColors.textHex(config.lineName))

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(Color(0xFFF5F5F5))),
    ) {
        WidgetHeader(config, lineColor, lineTextColor, passages.firstOrNull()?.isRealTime == true)

        if (error != null) {
            Box(
                modifier = GlanceModifier.fillMaxSize().padding(16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(errorLabel(error), style = errorTextStyle())
            }
        } else {
            val rows = passages.take(6)
            rows.forEachIndexed { i, passage ->
                PassageRow(passage, isFirst = i == 0, lineColor = lineColor, large = true)
                if (i < rows.lastIndex) WidgetDivider()
            }
        }
    }
}

// ── Shared composables ────────────────────────────────────────────────────────

@Composable
internal fun LineBadge(
    name: String,
    bgColor: Color,
    textColor: Color,
    fontSize: androidx.compose.ui.unit.TextUnit,
) {
    Box(
        modifier = GlanceModifier
            .background(ColorProvider(bgColor))
            .cornerRadius(100.dp)
            .padding(horizontal = 8.dp, vertical = 4.dp)
            .wrapContentWidth(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            name,
            style = TextStyle(
                color = ColorProvider(textColor),
                fontSize = fontSize,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

@Composable
private fun WidgetHeader(
    config: WidgetConfig,
    lineColor: Color,
    lineTextColor: Color,
    isRealTime: Boolean,
) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .background(ColorProvider(lineColor.copy(alpha = 0.10f)))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LineBadge(config.lineName, lineColor, lineTextColor, 13.sp)
        Spacer(GlanceModifier.width(10.dp))
        Column(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                config.stopName,
                style = TextStyle(
                    color = ColorProvider(Color(0xFF1A1A1A)),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                ),
                maxLines = 1,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "→ ${config.directionDisplay}",
                    style = TextStyle(color = ColorProvider(Color(0xFF666666)), fontSize = 10.sp),
                    maxLines = 1,
                )
                if (isRealTime) {
                    Spacer(GlanceModifier.width(4.dp))
                    Text(
                        "TR",
                        style = TextStyle(
                            color = ColorProvider(Color(0xFF43A047)),
                            fontSize = 8.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                }
            }
        }
    }
}

@Composable
private fun PassageRow(
    passage: WidgetPassage,
    isFirst: Boolean,
    lineColor: Color,
    large: Boolean = false,
) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = if (large) 10.dp else 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            passage.smartDelay,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = ColorProvider(
                    passage.urgencyColor(if (isFirst) lineColor else Color(0xFF444444))
                ),
                fontSize = if (isFirst) 15.sp else 13.sp,
                fontWeight = if (isFirst) FontWeight.Bold else FontWeight.Medium,
            ),
        )
        Text(
            passage.time,
            style = TextStyle(color = ColorProvider(Color(0xFF888888)), fontSize = 12.sp),
        )
    }
}

@Composable
private fun WidgetDivider() {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(1.dp)
            .background(ColorProvider(Color(0x14000000))),
    ) {}
}

private fun errorLabel(error: WidgetError) = when (error) {
    WidgetError.NO_PASSAGES   -> "Aucun passage prévu"
    WidgetError.NETWORK_ERROR -> "Erreur réseau"
}

private fun errorTextStyle() = TextStyle(
    color = ColorProvider(Color(0xFF888888)),
    fontSize = 12.sp,
)
