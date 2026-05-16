package com.alertetcl.android.ui.live

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.shared.viewmodels.AlertsViewModel
import com.alertetcl.shared.viewmodels.LiveVehiclesViewModel
import kotlinx.coroutines.launch

@Composable
fun DataSourceErrorsSheet(
    vehiclesError: String?,
    alertsError: String?,
    onRetryVehicles: suspend () -> Unit,
    onRetryAlerts: suspend () -> Unit,
    onDismiss: () -> Unit
) {
    val scope = rememberCoroutineScope()
    var isRetrying by remember { mutableStateOf(false) }

    Column(modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Warning, null, tint = MaterialTheme.colorScheme.tertiary, modifier = Modifier.size(24.dp))
            Spacer(Modifier.width(10.dp))
            Text("Erreurs de chargement", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        Spacer(Modifier.height(4.dp))
        Text(
            run {
                val h = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
                if (h >= 22 || h < 6)
                    "Il est probable que Grand Lyon coupe ses serveurs la nuit. Pas d'inquiétude, tout reviendra demain matin !"
                else
                    "Ces erreurs sont généralement temporaires. Réessayez dans quelques instants."
            },
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(16.dp))
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))

        if (alertsError != null) {
            ErrorRow(
                icon = Icons.Filled.Warning,
                iconTint = MaterialTheme.colorScheme.error,
                title = "Alertes TCL",
                error = alertsError,
                isRetrying = isRetrying
            ) {
                scope.launch {
                    isRetrying = true
                    onRetryAlerts()
                    isRetrying = false
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        if (vehiclesError != null) {
            ErrorRow(
                icon = Icons.Filled.DirectionsBus,
                iconTint = MaterialTheme.colorScheme.primary,
                title = "Véhicules en temps réel",
                error = vehiclesError,
                isRetrying = isRetrying
            ) {
                scope.launch {
                    isRetrying = true
                    onRetryVehicles()
                    isRetrying = false
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        Spacer(Modifier.height(8.dp))
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))

        // Retry all
        Button(
            onClick = {
                scope.launch {
                    isRetrying = true
                    if (vehiclesError != null) onRetryVehicles()
                    if (alertsError != null) onRetryAlerts()
                    isRetrying = false
                }
            },
            enabled = !isRetrying,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (isRetrying) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), color = MaterialTheme.colorScheme.onPrimary, strokeWidth = 2.dp)
                Spacer(Modifier.width(8.dp))
            } else {
                Icon(Icons.Filled.Refresh, null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
            }
            Text("Réessayer toutes les sources")
        }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
            Text("Fermer")
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun ErrorRow(
    icon: ImageVector,
    iconTint: Color,
    title: String,
    error: String,
    isRetrying: Boolean,
    onRetry: () -> Unit
) {
    Surface(color = MaterialTheme.colorScheme.errorContainer, tonalElevation = 0.dp, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, null, tint = iconTint, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(title, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
            }
            Spacer(Modifier.height(4.dp))
            Text(error, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onErrorContainer)
            Spacer(Modifier.height(8.dp))
            TextButton(
                onClick = onRetry,
                enabled = !isRetrying
            ) {
                if (isRetrying) {
                    CircularProgressIndicator(modifier = Modifier.size(12.dp), strokeWidth = 1.5.dp)
                    Spacer(Modifier.width(6.dp))
                }
                Text("Réessayer", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
