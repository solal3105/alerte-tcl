package com.alertetcl.android.ui.about

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.R
import com.alertetcl.android.ui.openUrl
import com.alertetcl.android.ui.theme.Tokens

/**
 * Onglet Info : Solal Gendrin d'abord, puis l'application, Open Projets, l'Open Data du Grand Lyon,
 * les sources et les liens. Toutes les couleurs viennent des jetons partagés.
 */
@Composable
fun AboutScreen() {
    val context = LocalContext.current
    val pm = context.packageManager
    val versionName = runCatching { pm.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "1.0"
    val versionCode = runCatching { pm.getPackageInfo(context.packageName, 0).longVersionCode }.getOrNull()?.toString() ?: ""

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item { HeroSection() }
        item { AppCard() }
        item { OpenProjetsCard() }
        item { OpenDataTribute() }
        item { SourcesCard() }
        item { LinksFooter() }
        item { VersionFooter(versionName, versionCode) }
    }
}

@Composable
private fun HeroSection() {
    val context = LocalContext.current
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = Modifier
                .size(104.dp)
                .background(Brush.linearGradient(listOf(Tokens.success, Tokens.success.copy(alpha = 0.7f))), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text("SG", color = Color.White, fontSize = 34.sp, fontWeight = FontWeight.Bold)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Solal Gendrin", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Surface(shape = RoundedCornerShape(50), color = Tokens.success.copy(alpha = 0.12f)) {
                Text(
                    "Conseiller métropolitain écologiste",
                    color = Tokens.success, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp)
                )
            }
        }
        Text(
            "Élu écologiste à la Métropole de Lyon, je développe Lyon Pocket pour rendre les transports en commun, le vélo et le stationnement plus simples à utiliser au quotidien.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 8.dp)
        )
        Button(
            onClick = { openUrl(context, "https://www.linkedin.com/in/solal-gendrin/") },
            colors = ButtonDefaults.buttonColors(containerColor = Tokens.accent, contentColor = Color.White),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(Icons.Filled.Send, null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text("Me suivre sur LinkedIn", fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun AppCard() {
    ElevatedCard(shape = MaterialTheme.shapes.large, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Image(
                    painter = painterResource(id = R.mipmap.ic_launcher),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(44.dp).clip(RoundedCornerShape(10.dp))
                )
                Column {
                    Text("Lyon Pocket", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("Les transports lyonnais, en direct.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Text(
                "Une application indépendante, née d'un usage quotidien des TCL : gratuite, sans publicité, sans compte. Aucune donnée personnelle n'est collectée.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SuggestionChip(onClick = {}, label = { Text("Gratuit") })
                SuggestionChip(onClick = {}, label = { Text("Sans pub") })
                SuggestionChip(onClick = {}, label = { Text("Sans tracking") })
            }
        }
    }
}

@Composable
private fun OpenProjetsCard() {
    val context = LocalContext.current
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                brush = Brush.linearGradient(listOf(Tokens.accent, Tokens.accent.copy(alpha = 0.78f))),
                shape = RoundedCornerShape(20.dp)
            )
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier.size(42.dp).background(Color.White.copy(alpha = 0.18f), RoundedCornerShape(11.dp)),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Filled.Map, null, tint = Color.White, modifier = Modifier.size(19.dp)) }
                Column {
                    Text("Open Projets by Vazy", fontWeight = FontWeight.SemiBold, color = Color.White, fontSize = 15.sp)
                    Text("Mon autre projet", style = MaterialTheme.typography.bodySmall, color = Color.White.copy(alpha = 0.7f), fontWeight = FontWeight.Medium)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Vous travaillez dans une collectivité ou vous êtes élu ?", fontWeight = FontWeight.Bold, color = Color.White, style = MaterialTheme.typography.bodyMedium)
                Text(
                    "Avec Vazy, société à mission villeurbannaise, on a construit Open Projets : une carte interactive que chaque commune peut déployer pour informer ses habitants sur ses chantiers et projets d'aménagement.",
                    color = Color.White.copy(alpha = 0.9f), fontSize = 13.sp, lineHeight = 18.sp
                )
                Text(
                    "La carte reprend votre logo, vos couleurs, vos catégories. Vos agents ajoutent les projets en quelques clics. Les habitants consultent depuis leur téléphone, sans compte, sans téléchargement.",
                    color = Color.White.copy(alpha = 0.9f), fontSize = 13.sp, lineHeight = 18.sp
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                TintedLink("Découvrir Open Projets", filled = true) { openUrl(context, "https://openprojets.com/home") }
                TintedLink("Voir la carte de la Métropole de Lyon", filled = false) { openUrl(context, "https://openprojets.com/default") }
            }
        }
    }
}

/** Lien sur une carte colorée : plein (blanc sur accent) ou discret (blanc translucide). */
@Composable
private fun TintedLink(title: String, filled: Boolean, onClick: () -> Unit) {
    val text = if (filled) Tokens.accent else Color.White.copy(alpha = 0.9f)
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = if (filled) Color.White else Color.White.copy(alpha = 0.14f),
        modifier = Modifier.fillMaxWidth().clickable { onClick() }
    ) {
        Row(
            modifier = Modifier.padding(vertical = 11.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, color = text, fontWeight = if (filled) FontWeight.SemiBold else FontWeight.Medium, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.width(6.dp))
            Icon(Icons.Outlined.OpenInNew, null, tint = text, modifier = Modifier.size(14.dp))
        }
    }
}

@Composable
private fun OpenDataTribute() {
    val context = LocalContext.current
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                brush = Brush.linearGradient(listOf(Tokens.success, Tokens.success.copy(alpha = 0.78f))),
                shape = RoundedCornerShape(20.dp)
            )
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    modifier = Modifier.size(36.dp).background(Color.White.copy(alpha = 0.18f), CircleShape),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Filled.Favorite, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
                Text("Merci à l'Open Data du Grand Lyon", fontWeight = FontWeight.SemiBold, color = Color.White, fontSize = 15.sp)
            }
            Text(
                "Cette app n'existerait pas sans le travail remarquable des équipes Open Data du Grand Lyon. " +
                    "Position des bus en temps réel, alertes, travaux, parkings, Vélo'v : tout est mis à disposition librement, " +
                    "sous licence ouverte. Un travail souvent invisible, qui rend possible des projets citoyens comme celui-ci.",
                color = Color.White.copy(alpha = 0.92f),
                fontSize = 13.sp
            )
            Surface(
                shape = RoundedCornerShape(50),
                color = Color.White,
                modifier = Modifier.clickable { openUrl(context, "https://data.grandlyon.com") }
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("data.grandlyon.com", color = Tokens.success, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    Icon(Icons.Outlined.OpenInNew, null, tint = Tokens.success, modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}

@Composable
private fun SourcesCard() {
    ElevatedCard(shape = MaterialTheme.shapes.large, modifier = Modifier.fillMaxWidth()) {
        ListItem(
            headlineContent = { Text("Sources de données", style = MaterialTheme.typography.titleMedium) },
            leadingContent = { SectionIcon(Icons.Filled.Wifi, Tokens.accent) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent)
        )
        HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
        SourceItem("Position des véhicules", "SIRI-Lite, temps réel", Icons.Filled.LocationOn, Tokens.success)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Arrêts, lignes, horaires", "GTFS", Icons.Filled.Tram, Tokens.accent)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Alertes et perturbations", "Flux officiel TCL", Icons.Filled.Warning, Tokens.warning)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Travaux", "Chantiers du réseau et de la voirie", Icons.Filled.Build, Tokens.warning)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Parkings et Vélo'v", "Disponibilité en temps réel", Icons.Filled.DirectionsCar, Tokens.accent)
        Text(
            "Toutes les données sont publiées par le Grand Lyon sous licence ouverte (Etalab / ODbL).",
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun LinksFooter() {
    val context = LocalContext.current
    ElevatedCard(shape = MaterialTheme.shapes.large, modifier = Modifier.fillMaxWidth()) {
        LinkItem(
            title = "Site officiel",
            subtitle = "lyon-pocket.netlify.app",
            icon = Icons.Filled.Public,
            tint = Tokens.accent,
            onClick = { openUrl(context, "https://lyon-pocket.netlify.app/") }
        )
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        LinkItem(
            title = "Politique de confidentialité",
            subtitle = "Aucune donnée personnelle collectée",
            icon = Icons.Filled.Lock,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            onClick = { openUrl(context, "https://lyon-pocket.netlify.app/privacy") }
        )
    }
}

@Composable
private fun VersionFooter(version: String, build: String) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            "Lyon Pocket $version" + if (build.isNotEmpty()) " ($build)" else "",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text("Fait à Villeurbanne, avec ♥", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
        Text(
            "Application indépendante, sans aucune affiliation à SYTRAL Mobilités, Keolis Lyon ou TCL.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.outline,
            textAlign = TextAlign.Center
        )
    }
}

// ── helpers ────────────────────────────────────────────────────────

@Composable
private fun SectionIcon(icon: ImageVector, tint: Color) {
    Box(
        modifier = Modifier.size(36.dp).background(tint.copy(alpha = 0.12f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun SourceItem(title: String, subtitle: String, icon: ImageVector, tint: Color) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = { Text(subtitle) },
        leadingContent = {
            Box(
                modifier = Modifier.size(36.dp).background(tint.copy(alpha = 0.12f), MaterialTheme.shapes.small),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp))
            }
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent)
    )
}

@Composable
private fun LinkItem(title: String, subtitle: String, icon: ImageVector, tint: Color, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = { Text(subtitle) },
        leadingContent = {
            Box(
                modifier = Modifier.size(36.dp).background(tint.copy(alpha = 0.12f), MaterialTheme.shapes.small),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp))
            }
        },
        trailingContent = {
            Icon(Icons.Outlined.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp))
        },
        modifier = Modifier.clickable { onClick() },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent)
    )
}
