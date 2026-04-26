package com.alertetcl.android.ui.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun SettingsScreen() {
    val context = LocalContext.current
    val pm = context.packageManager
    val versionName = runCatching { pm.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "1.0"

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        item {
            SectionHeader("Notifications")
        }
        item {
            ListItem(
                leadingContent = { Icon(Icons.Filled.NotificationsActive, contentDescription = null) },
                headlineContent = { Text("Permissions") },
                supportingContent = { Text("Activer les alertes critiques") },
                modifier = Modifier.clickable {
                    val intent = Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.packageName)
                    }
                    context.startActivity(intent)
                }
            )
        }

        item { SectionHeader("Premium") }
        item {
            ListItem(
                leadingContent = { Icon(Icons.Filled.WorkspacePremium, contentDescription = null, tint = Color(0xFFFFB300)) },
                headlineContent = { Text("Soutenir l'application") },
                supportingContent = { Text("Abonnement mensuel ou annuel") }
            )
        }

        item { SectionHeader("À propos") }
        item {
            ListItem(
                leadingContent = { Icon(Icons.Filled.Info, contentDescription = null) },
                headlineContent = { Text("Version") },
                trailingContent = { Text(versionName, color = Color.Gray) }
            )
        }
        item {
            ListItem(
                leadingContent = { Icon(Icons.Filled.Link, contentDescription = null) },
                headlineContent = { Text("Données") },
                supportingContent = { Text("Grand Lyon · data.grandlyon.com") },
                modifier = Modifier.clickable {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://data.grandlyon.com")))
                }
            )
        }
        item {
            ListItem(
                leadingContent = { Icon(Icons.Filled.PrivacyTip, contentDescription = null) },
                headlineContent = { Text("Politique de confidentialité") },
                modifier = Modifier.clickable {
                    context.startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse("https://solalgendrin.github.io/alerte-tcl/privacy")))
                }
            )
        }
        item {
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            Text(
                "Données : Grand Lyon · TCL · SYTRAL Mobilités",
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                fontSize = 11.sp,
                color = Color.Gray
            )
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text,
        modifier = Modifier.fillMaxWidth().padding(start = 16.dp, top = 16.dp, bottom = 4.dp),
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        color = Color.Gray
    )
}
