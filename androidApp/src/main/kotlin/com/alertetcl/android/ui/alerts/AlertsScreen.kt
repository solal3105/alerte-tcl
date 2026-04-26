package com.alertetcl.android.ui.alerts

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.android.ui.lines.LinesListScreen
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.BusLine
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransitLine
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.services.BusLineService
import com.alertetcl.shared.services.TransitLineService
import com.alertetcl.shared.viewmodels.AlertsViewModel

@Composable
fun AlertsScreen() {
    val viewModel = remember { AlertsViewModel() }
    DisposableEffect(Unit) {
        viewModel.startPolling()
        onDispose { viewModel.dispose() }
    }
    val alerts by viewModel.alerts.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.errorMessage.collectAsState()

    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())

    val transitLines = produceState<List<TransitLine>>(initialValue = emptyList()) {
        value = runCatching { TransitLineService.shared.fetchTransitLines() }.getOrDefault(emptyList())
    }
    val busLines = produceState<List<BusLine>>(initialValue = emptyList()) {
        value = runCatching { BusLineService.shared.fetchBusLines() }.getOrDefault(emptyList())
    }
    val allLineCodes = remember(transitLines.value, busLines.value) {
        val tl = transitLines.value.map { it.name to TransportMode.detectFromLine(it.name) }
        val bl = busLines.value.map { it.name to TransportMode.detectFromLine(it.name) }
        (tl + bl).distinctBy { it.first }
    }

    val subscribedAlerts = remember(alerts, favorites) {
        alerts.filter { it.ligneCom in favorites }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF2F2F7))) {
        when {
            alerts.isEmpty() && isLoading -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
            alerts.isEmpty() && error != null -> {
                Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                    Text("Erreur : $error")
                }
            }
            else -> {
                LazyColumn(
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    item { StatusBanner(subscribedAlerts.size, favorites.isEmpty()) }

                    if (favorites.isNotEmpty()) {
                        item { SectionTitle("Mes lignes (${favorites.size})") }
                        items(favorites.toList().sorted(), key = { "fav_$it" }) { line ->
                            val lineAlerts = subscribedAlerts.filter { it.ligneCom == line }
                            FavoriteLineCard(line, lineAlerts)
                        }
                    }

                    item { SectionTitle("Toutes les alertes (${alerts.size})") }
                    items(alerts, key = { "alert_${it.id}" }) { alert -> AlertCard(alert) }

                    if (allLineCodes.isNotEmpty()) {
                        item { SectionTitle("Toutes les lignes") }
                        item {
                            Box(modifier = Modifier.fillMaxWidth().height(700.dp)) {
                                LinesListScreen(allLineCodes, alerts)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusBanner(alertCount: Int, noSubscriptions: Boolean) {
    val (color, icon, text) = when {
        noSubscriptions -> Triple(Color(0xFF1E88E5), Icons.Filled.NotificationsActive,
            "Abonnez-vous à des lignes pour recevoir des alertes")
        alertCount == 0 -> Triple(Color(0xFF43A047), Icons.Filled.CheckCircle,
            "Toutes vos lignes sont normales")
        else -> Triple(Color(0xFFE53935), Icons.Filled.Warning,
            "$alertCount perturbation" + (if (alertCount > 1) "s" else "") + " sur vos lignes")
    }
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = color.copy(alpha = 0.10f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(
                modifier = Modifier.size(38.dp).clip(RoundedCornerShape(50)).background(color),
                contentAlignment = Alignment.Center
            ) { Icon(icon, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
            Text(text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text, fontSize = 16.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp)
    )
}

@Composable
private fun FavoriteLineCard(line: String, lineAlerts: List<TCLAlert>) {
    val severity = lineAlerts.minByOrNull { it.severity.sortOrder }?.severity
    val color = when (severity) {
        AlertSeverity.MAJOR      -> Color(0xFFE53935)
        AlertSeverity.DISRUPTION -> Color(0xFFFB8C00)
        AlertSeverity.INFO       -> Color(0xFF1E88E5)
        null                     -> Color(0xFF43A047)
    }
    Surface(shape = RoundedCornerShape(16.dp), color = Color.White, modifier = Modifier.fillMaxWidth()) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth().background(color).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                LineBadge(line, big = true)
                Spacer(Modifier.width(12.dp))
                Text(
                    if (lineAlerts.isEmpty()) "Aucune perturbation" else "${lineAlerts.size} alerte" + if (lineAlerts.size > 1) "s" else "",
                    color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp
                )
            }
            lineAlerts.forEach { a ->
                HorizontalDivider()
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        SeverityDot(a.severity)
                        Spacer(Modifier.width(6.dp))
                        Text(a.titre, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(a.message, fontSize = 12.sp, color = Color.DarkGray)
                }
            }
        }
    }
}

@Composable
private fun AlertCard(alert: TCLAlert) {
    Surface(shape = RoundedCornerShape(14.dp), color = Color.White, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                LineBadge(alert.ligneCom)
                Spacer(modifier = Modifier.width(8.dp))
                Text(alert.titre, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(alert.message, fontSize = 12.sp)
            Spacer(modifier = Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                SeverityDot(alert.severity)
                Spacer(modifier = Modifier.width(6.dp))
                Text(alert.severity.displayName, fontSize = 11.sp, color = Color.Gray)
            }
        }
    }
}

@Composable
private fun LineBadge(line: String, big: Boolean = false) {
    val bg = colorFromHex(LineColors.backgroundHex(line))
    val tx = colorFromHex(LineColors.textHex(line))
    val w = if (big) 50.dp else 36.dp
    val h = if (big) 30.dp else 22.dp
    Box(
        modifier = Modifier.size(width = w, height = h).clip(RoundedCornerShape(6.dp)).background(bg),
        contentAlignment = Alignment.Center
    ) { Text(line, color = tx, fontSize = if (big) 14.sp else 11.sp, fontWeight = FontWeight.Bold) }
}

@Composable
private fun SeverityDot(severity: AlertSeverity) {
    val color = when (severity) {
        AlertSeverity.MAJOR      -> Color(0xFFE53935)
        AlertSeverity.DISRUPTION -> Color(0xFFFB8C00)
        AlertSeverity.INFO       -> Color(0xFF1E88E5)
    }
    Box(modifier = Modifier.size(10.dp).clip(RoundedCornerShape(50)).background(color))
}
