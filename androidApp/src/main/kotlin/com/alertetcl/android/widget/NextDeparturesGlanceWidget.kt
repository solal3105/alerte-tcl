package com.alertetcl.android.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.LineColors
import androidx.glance.appwidget.GlanceAppWidgetManager
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
            DpSize(72.dp, 72.dp),   // 1×1: nano
            DpSize(148.dp, 72.dp),  // 2×1: slim
            DpSize(148.dp, 148.dp), // 2×2: standard
            DpSize(222.dp, 148.dp), // 3×2: wide
            DpSize(222.dp, 222.dp), // 3×3: large
        )
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val config = WidgetConfigStore.load(context, appWidgetId)

        if (config == null) {
            provideContent { NotConfiguredContent("", context, appWidgetId) }
            return
        }

        val displayConfig = config.withResolvedDestination()

        val (passages, fetchError) = runCatching {
            WidgetPassageService.fetchPassages(context, config.stopId, config.lineName, displayConfig.destinationName) to null
        }.getOrElse {
            // réseau KO (Doze, App Standby RARE…) : fallback sur le cache jusqu'à 4 h
            val cached = WidgetPassageCache.load(context, config.stopId, config.lineName, displayConfig.destinationName)
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
            size.height <= 72.dp && size.width <= 72.dp -> NanoContent(config, passages, error)
            size.height <= 72.dp                         -> SlimContent(config, passages, error)
            size.width <= 148.dp                         -> StandardContent(config, passages, error)
            size.height <= 148.dp                        -> WideContent(config, passages, error)
            else                                         -> LargeContent(config, passages, error)
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
        Intent(context, NextDeparturesWidgetConfigActivity::class.java)
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
                color = ColorProvider(Color(0xFF595959)),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
            ),
        )
    }
}

// ── Nano layout (1×1) ─────────────────────────────────────────────────────────

@Composable
private fun NanoContent(
    config: WidgetConfig,
    passages: List<WidgetPassage>,
    error: WidgetError?,
) {
    val lineColor     = colorFromHex(LineColors.backgroundHex(config.lineName))
    val lineTextColor = colorFromHex(LineColors.textHex(config.lineName))
    val next          = passages.firstOrNull()

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(Color(0xFFF5F5F5)))
            .padding(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        LineBadge(config.lineName, lineColor, lineTextColor, 10.sp)
        Spacer(GlanceModifier.height(4.dp))
        Text(
            if (error != null || next == null) "—" else next.compactDelay,
            style = TextStyle(
                color = ColorProvider(next?.urgencyColor(lineColor) ?: Color(0xFF595959)),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
            ),
            maxLines = 1,
        )
        if (error == null && passages.size > 1) {
            Text(
                "puis ${passages[1].compactDelay}",
                style = TextStyle(
                    color = ColorProvider(Color(0xFF595959)),
                    fontSize = 9.sp,
                ),
                maxLines = 1,
            )
        }
    }
}

// ── Slim layout (2×1) ─────────────────────────────────────────────────────────

@Composable
private fun SlimContent(
    config: WidgetConfig,
    passages: List<WidgetPassage>,
    error: WidgetError?,
) {
    val lineColor     = colorFromHex(LineColors.backgroundHex(config.lineName))
    val lineTextColor = colorFromHex(LineColors.textHex(config.lineName))

    Row(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(Color(0xFFF5F5F5)))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LineBadge(config.lineName, lineColor, lineTextColor, 11.sp)
        Spacer(GlanceModifier.width(10.dp))
        if (error != null) {
            Text(errorLabel(error), style = errorTextStyle())
        } else {
            val next      = passages.getOrNull(0)
            val following = passages.getOrNull(1)
            Column(modifier = GlanceModifier.fillMaxWidth()) {
                Text(
                    config.stopName,
                    style = TextStyle(color = ColorProvider(Color(0xFF666666)), fontSize = 9.sp),
                    maxLines = 1,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        next?.compactDelay ?: "—",
                        style = TextStyle(
                            color = ColorProvider(next?.urgencyColor(lineColor) ?: Color(0xFF595959)),
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                    if (following != null) {
                        Spacer(GlanceModifier.width(6.dp))
                        Text(
                            "puis ${following.compactDelay}",
                            style = TextStyle(
                                color = ColorProvider(Color(0xFF595959)),
                                fontSize = 11.sp,
                            ),
                        )
                    }
                }
            }
        }
    }
}

// ── Standard layout (2×2) ────────────────────────────────────────────────────

@Composable
private fun StandardContent(
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
        // Single-line compact header
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .background(ColorProvider(lineColor.copy(alpha = 0.10f)))
                .padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            LineBadge(config.lineName, lineColor, lineTextColor, 11.sp)
            Spacer(GlanceModifier.width(8.dp))
            Text(
                config.stopName,
                modifier = GlanceModifier.fillMaxWidth(),
                style = TextStyle(
                    color = ColorProvider(Color(0xFF1A1A1A)),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                ),
                maxLines = 1,
            )
        }

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
                PassageRow(passage, isFirst = i == 0, lineColor = lineColor, compact = true)
                if (i < rows.lastIndex) WidgetDivider()
            }
        }
    }
}

// ── Wide layout (3×2) ─────────────────────────────────────────────────────────

@Composable
private fun WideContent(
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
        // Single-line header with stop + direction visible thanks to wider layout
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .background(ColorProvider(lineColor.copy(alpha = 0.10f)))
                .padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            LineBadge(config.lineName, lineColor, lineTextColor, 11.sp)
            Spacer(GlanceModifier.width(8.dp))
            Text(
                config.stopName,
                style = TextStyle(
                    color = ColorProvider(Color(0xFF1A1A1A)),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                ),
                maxLines = 1,
            )
            Spacer(GlanceModifier.width(4.dp))
            Text(
                "→ ${config.directionDisplay}",
                modifier = GlanceModifier.fillMaxWidth(),
                style = TextStyle(color = ColorProvider(Color(0xFF666666)), fontSize = 10.sp),
                maxLines = 1,
            )
        }

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

// ── Large layout (3×3) ────────────────────────────────────────────────────────

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
    // Light-background badges (white for generic buses, yellow for TB trolleys…) need
    // a 1dp border so the pill shape remains visible on the widget's near-white background.
    // Simple linear approximation of luminance — close enough for this threshold check.
    val isLight = (0.2126f * bgColor.red + 0.7152f * bgColor.green + 0.0722f * bgColor.blue) > 0.55f

    val pillContent: @Composable () -> Unit = {
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

    if (isLight) {
        Box(
            modifier = GlanceModifier
                .background(ColorProvider(Color(0xFFCCCCCC)))
                .cornerRadius(100.dp)
                .padding(1.dp)
                .wrapContentWidth(),
        ) { pillContent() }
    } else {
        pillContent()
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
                            color = ColorProvider(Color(0xFF2E7D32)),
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
    compact: Boolean = false,
) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = when { large -> 10.dp; compact -> 4.dp; else -> 8.dp }),
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
            style = TextStyle(color = ColorProvider(Color(0xFF595959)), fontSize = 12.sp),
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
    color = ColorProvider(Color(0xFF595959)),
    fontSize = 12.sp,
)
