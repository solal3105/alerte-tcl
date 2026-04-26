package com.alertetcl.android.ui.alerts

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.TCLAlert
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

    Box(modifier = Modifier.fillMaxSize()) {
        when {
            alerts.isEmpty() && isLoading -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
            alerts.isEmpty() && error != null -> {
                Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                    Text("Erreur: $error")
                }
            }
            else -> {
                LazyColumn(
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(alerts, key = { it.id }) { alert ->
                        AlertCard(alert)
                    }
                }
            }
        }
    }
}

@Composable
private fun AlertCard(alert: TCLAlert) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                LineBadge(alert.ligneCom)
                Spacer(modifier = Modifier.width(8.dp))
                Text(alert.titre, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(alert.message, fontSize = 13.sp)
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
private fun LineBadge(line: String) {
    val bg = colorFromHex(LineColors.backgroundHex(line))
    val tx = colorFromHex(LineColors.textHex(line))
    Box(
        modifier = Modifier
            .size(width = 36.dp, height = 22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(bg),
        contentAlignment = Alignment.Center
    ) {
        Text(line, color = tx, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
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
