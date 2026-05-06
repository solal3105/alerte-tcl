package com.alertetcl.android.ui.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val groupedBg = Color(0xFFF2F2F7)
private val secondary = Color(0xFF8E8E93)
private val iOSBlue   = Color(0xFF007AFF)
private val iOSPurple = Color(0xFFAF52DE)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onOpenWidgetStops: () -> Unit = {}) {
    val context = LocalContext.current
    val pm = context.packageManager
    val versionName = runCatching { pm.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "1.0"

    var showWidgetHelp by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(groupedBg),
        contentPadding = PaddingValues(top = 16.dp, bottom = 32.dp)
    ) {
        // Header / titre principal
        item {
            Text("Paramètres",
                fontSize = 32.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
        }

        // Section Widget Prochains Passages
        item {
            SectionHeader("WIDGET PROCHAINS PASSAGES")
            SettingsCard {
                SettingsRow(
                    icon = Icons.Filled.HelpOutline,
                    iconTint = iOSBlue,
                    title = "Comment configurer le widget",
                    subtitle = "Guide étape par étape",
                    onClick = { showWidgetHelp = true }
                )
                Divider()
                SettingsRow(
                    icon = Icons.Filled.Tram,
                    iconTint = iOSPurple,
                    title = "Mes arrêts widget",
                    subtitle = "Gérer les arrêts sauvegardés",
                    onClick = onOpenWidgetStops
                )
            }
            SectionFooter(
                "Ajoutez des arrêts depuis la fiche d'un arrêt sur la carte, " +
                "puis configurez le widget sur votre écran d'accueil."
            )
        }

        // Section À propos
        item {
            SectionHeader("À PROPOS")
            SettingsCard {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Version", fontSize = 15.sp, modifier = Modifier.weight(1f))
                    Text(versionName, fontSize = 15.sp, color = secondary)
                }
                Divider()
                LinkRow(
                    title = "Données",
                    trailing = "Grand Lyon",
                    onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://data.grandlyon.com")))
                    }
                )
                Divider()
                LinkRow(
                    title = "Politique de confidentialité",
                    trailing = null,
                    onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW,
                            Uri.parse("https://solalgendrin.github.io/alerte-tcl/privacy")))
                    }
                )
            }
        }
    }

    if (showWidgetHelp) {
        ModalBottomSheet(
            onDismissRequest = { showWidgetHelp = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            WidgetHelpView()
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        color = secondary,
        modifier = Modifier.padding(start = 32.dp, top = 24.dp, bottom = 6.dp)
    )
}

@Composable
private fun SectionFooter(text: String) {
    Text(
        text, fontSize = 12.sp, color = secondary,
        modifier = Modifier.padding(start = 32.dp, end = 32.dp, top = 6.dp)
    )
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        shape = RoundedCornerShape(10.dp), color = Color.White,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
    ) { Column(content = content) }
}

@Composable
private fun Divider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 56.dp)
            .height(0.5.dp)
            .background(Color(0xFFC6C6C8).copy(alpha = 0.5f))
    )
}

@Composable
private fun SettingsRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconTint: Color,
    title: String,
    subtitle: String?,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.size(28.dp),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = iconTint, modifier = Modifier.size(22.dp)) }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.Medium)
            if (subtitle != null) Text(subtitle, fontSize = 12.sp, color = secondary)
        }
        Icon(Icons.Filled.ChevronRight, null, tint = secondary, modifier = Modifier.size(14.dp))
    }
}

@Composable
private fun LinkRow(title: String, trailing: String?, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontSize = 15.sp, modifier = Modifier.weight(1f))
        if (trailing != null) {
            Text(trailing, fontSize = 15.sp, color = secondary)
            Spacer(Modifier.width(6.dp))
        }
        Icon(Icons.Filled.NorthEast, null, tint = secondary, modifier = Modifier.size(12.dp))
    }
}

// ─── Widget Help View ────────────────────────────────────────────────────
@Composable
private fun WidgetHelpView() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text("Configurer le widget", fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(
            "Ajoutez le widget « Prochains Passages » sur votre écran d'accueil pour " +
            "voir vos arrêts favoris en un coup d'œil.",
            fontSize = 14.sp, color = secondary
        )

        StepRow(
            number = 1,
            title = "Sélectionnez vos arrêts",
            description = "Touchez un arrêt sur la carte puis « Ajouter au widget »."
        )
        StepRow(
            number = 2,
            title = "Maintenez votre écran d'accueil",
            description = "Une fois en mode édition, touchez le bouton + en haut à gauche."
        )
        StepRow(
            number = 3,
            title = "Choisissez Alerte TCL",
            description = "Recherchez « Alerte TCL », puis ajoutez le widget « Prochains Passages »."
        )
        StepRow(
            number = 4,
            title = "Personnalisez l'arrêt",
            description = "Touchez le widget pour choisir lequel de vos arrêts sauvegardés afficher."
        )
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun StepRow(number: Int, title: String, description: String) {
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(
            modifier = Modifier.size(28.dp).clip(CircleShape).background(iOSBlue),
            contentAlignment = Alignment.Center
        ) {
            Text("$number", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text(description, fontSize = 13.sp, color = secondary)
        }
    }
}
