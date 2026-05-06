package com.alertetcl.android.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.Button
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.shared.services.TransitStopService
import kotlinx.coroutines.flow.first

class NextDeparturesGlanceWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val store = FavoritesStore(context)
        val stopIds = store.widgetStops.first()

        val data: List<Pair<String, List<String>>> = stopIds.take(2).map { stopId ->
            val passages = runCatching {
                TransitStopService.shared.fetchPassagesForStop(stopId)
            }.getOrDefault(emptyList())
            val name = "Arrêt #$stopId"
            val lines = passages.take(3).map { p ->
                "${p.ligne} → ${p.direction} · ${p.delaipassage}"
            }
            name to lines
        }

        provideContent { WidgetContent(data) }
    }

    @Composable
    private fun WidgetContent(stops: List<Pair<String, List<String>>>) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(androidx.compose.ui.graphics.Color.White))
                .padding(12.dp)
                .cornerRadius(12.dp)
        ) {
            Text(
                "Prochains passages",
                style = TextStyle(fontWeight = FontWeight.Bold)
            )
            Spacer(modifier = GlanceModifier.height(6.dp))
            if (stops.isEmpty()) {
                Text("Ajoute un arrêt depuis l'app",
                    style = TextStyle(fontWeight = FontWeight.Normal))
            } else {
                stops.forEach { (name, lines) ->
                    Text(name, style = TextStyle(fontWeight = FontWeight.Medium))
                    lines.forEach { Text("  $it") }
                    Spacer(modifier = GlanceModifier.height(4.dp))
                }
            }
        }
    }
}

class NextDeparturesGlanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextDeparturesGlanceWidget()
}
