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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material3.Button
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
import com.alertetcl.android.ui.theme.StatusSuccess
import com.alertetcl.android.ui.theme.StatusWarning

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
        item { ManifestoCard() }
        item { CreatorCard() }
        item { OpenProjetsCard() }
        item { OpenDataTribute() }
        item { SourcesCard() }
        item { ContactCard() }
        item { LinksFooter() }
        item { VersionFooter(versionName, versionCode) }
    }
}

@Composable
private fun HeroSection() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Image(
            painter = painterResource(id = R.mipmap.ic_launcher),
            contentDescription = "App icon",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(88.dp)
                .clip(MaterialTheme.shapes.extraLarge)
        )
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                "Lyon Pocket",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold
            )
            Text(
                "Les transports lyonnais, en direct.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun ManifestoCard() {
    ElevatedCard(
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
            ListItem(
                headlineContent = {
                    Text("Respectueuse, par conception", style = MaterialTheme.typography.titleMedium)
                },
                leadingContent = { SectionIcon(Icons.Filled.CheckCircle, StatusSuccess) },
                colors = ListItemDefaults.colors(containerColor = Color.Transparent)
            )
            Text(
                "Lyon Pocket est gratuit, sans publicité, sans compte. Aucune donnée personnelle n'est collectée. C'est tout.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 4.dp)
            )
            Row(
                modifier = Modifier.padding(start = 12.dp, end = 12.dp, bottom = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SuggestionChip(onClick = {}, label = { Text("Gratuit") })
                SuggestionChip(onClick = {}, label = { Text("Sans pub") })
                SuggestionChip(onClick = {}, label = { Text("Sans tracking") })
            }
        }
    }
}

@Composable
private fun CreatorCard() {
    ElevatedCard(
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        ListItem(
            headlineContent = { Text("Derrière Lyon Pocket", style = MaterialTheme.typography.titleMedium) },
            leadingContent = { SectionIcon(Icons.Filled.Person, MaterialTheme.colorScheme.primary) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent)
        )
        Text(
            "Solal Gendrin, conseiller métropolitain à Lyon. Lyon Pocket est un projet personnel, né d'un usage quotidien des TCL.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp)
        )
    }
}

@Composable
private fun OpenProjetsCard() {
    val context = LocalContext.current
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                brush = Brush.linearGradient(listOf(Color(0xFF1F3399), Color(0xFF47249E))),
                shape = RoundedCornerShape(20.dp)
            )
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .background(Color.White.copy(alpha = 0.18f), RoundedCornerShape(11.dp)),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Filled.Map, null, tint = Color.White, modifier = Modifier.size(19.dp)) }
                Column {
                    Text("Open Projets by Vazy", fontWeight = FontWeight.SemiBold, color = Color.White, fontSize = 15.sp)
                    Text("Mon autre projet", style = MaterialTheme.typography.bodySmall, color = Color.White.copy(alpha = 0.6f), fontWeight = FontWeight.Medium)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "Vous travaillez dans une collectivité ou vous êtes élu ?",
                    fontWeight = FontWeight.Bold, color = Color.White, style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    "Avec Vazy, société à mission villeurbannaise, on a construit Open Projets : une carte interactive que chaque commune peut déployer pour informer ses habitants sur ses chantiers et projets d'aménagement.",
                    color = Color.White.copy(alpha = 0.88f), fontSize = 13.sp, lineHeight = 18.sp
                )
                Text(
                    "La carte reprend votre logo, vos couleurs, vos catégories. Vos agents ajoutent les projets en quelques clics. Les habitants consultent depuis leur téléphone, sans compte, sans téléchargement.",
                    color = Color.White.copy(alpha = 0.88f), fontSize = 13.sp, lineHeight = 18.sp
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = Color.White,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { openUrl(context, "https://openprojets.com/home") }
                ) {
                    Row(
                        modifier = Modifier.padding(vertical = 11.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Découvrir Open Projets", color = Color(0xFF1F3399), fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.width(6.dp))
                        Icon(Icons.Outlined.OpenInNew, null, tint = Color(0xFF1F3399), modifier = Modifier.size(14.dp))
                    }
                }
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = Color.White.copy(alpha = 0.12f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { openUrl(context, "https://openprojets.com/default") }
                ) {
                    Row(
                        modifier = Modifier.padding(vertical = 11.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Voir la carte de la Métropole de Lyon", color = Color.White.copy(alpha = 0.85f), fontWeight = FontWeight.Medium, style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.width(6.dp))
                        Icon(Icons.Outlined.OpenInNew, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(14.dp))
                    }
                }
            }
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
                brush = Brush.linearGradient(listOf(Color(0xFF0A8D4D), Color(0xFF0F6B8C))),
                shape = RoundedCornerShape(20.dp)
            )
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color.White.copy(alpha = 0.18f), CircleShape),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Filled.Favorite, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
                Text("Merci à l'Open Data du Grand Lyon", fontWeight = FontWeight.SemiBold, color = Color.White, fontSize = 15.sp)
            }
            Text(
                "Cette app n'existerait pas sans le travail remarquable des équipes Open Data du Grand Lyon. " +
                    "Position des bus en temps réel, alertes, travaux, parkings : tout est mis à disposition librement, " +
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
                    Text("data.grandlyon.com", color = Color(0xFF0A8D4D), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    Icon(Icons.Outlined.OpenInNew, null, tint = Color(0xFF0A8D4D), modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}

@Composable
private fun SourcesCard() {
    ElevatedCard(
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        ListItem(
            headlineContent = { Text("Sources de données", style = MaterialTheme.typography.titleMedium) },
            leadingContent = { SectionIcon(Icons.Filled.Wifi, MaterialTheme.colorScheme.primary) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent)
        )
        HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
        SourceItem("Position des véhicules", "SIRI-Lite, temps réel", Icons.Filled.LocationOn, StatusSuccess)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Arrêts, lignes, horaires", "GTFS", Icons.Filled.Tram, MaterialTheme.colorScheme.primary)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Alertes & perturbations", "Flux officiel TCL", Icons.Filled.Warning, StatusWarning)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Travaux", "Chantiers du réseau et de la voirie", Icons.Filled.Build, StatusWarning)
        HorizontalDivider(modifier = Modifier.padding(start = 72.dp, end = 16.dp))
        SourceItem("Parkings P+R", "Occupation en temps réel", Icons.Filled.DirectionsCar, MaterialTheme.colorScheme.tertiary)
        Text(
            "Toutes les données sont publiées par le Grand Lyon sous licence ouverte (Etalab / ODbL).",
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun ContactCard() {
    val context = LocalContext.current
    ElevatedCard(
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(bottom = 16.dp)) {
            ListItem(
                headlineContent = { Text("Une idée ? Un bug ?", style = MaterialTheme.typography.titleMedium) },
                leadingContent = { SectionIcon(Icons.Filled.Forum, MaterialTheme.colorScheme.error) },
                colors = ListItemDefaults.colors(containerColor = Color.Transparent)
            )
            Text(
                "Suggestions, retours, propositions d'évolution : écrivez-moi sur LinkedIn, je lis tout.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = { openUrl(context, "https://www.linkedin.com/in/solal-gendrin/") },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Icon(Icons.Filled.Send, null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text("Me contacter sur LinkedIn")
            }
        }
    }
}

@Composable
private fun LinksFooter() {
    val context = LocalContext.current
    ElevatedCard(
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        LinkItem(
            title = "Site officiel",
            subtitle = "lyon-pocket.netlify.app",
            icon = Icons.Filled.Public,
            tint = MaterialTheme.colorScheme.secondary,
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
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            "Lyon Pocket " + if (build.isNotEmpty()) " ()" else "",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            "Fait à Villeurbanne, avec ♥",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.outline
        )
    }
}

// ── helpers ────────────────────────────────────────────────────────

@Composable
private fun SectionIcon(icon: ImageVector, tint: Color) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .background(tint.copy(alpha = 0.12f), CircleShape),
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
                modifier = Modifier
                    .size(36.dp)
                    .background(tint.copy(alpha = 0.12f), MaterialTheme.shapes.small),
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
                modifier = Modifier
                    .size(36.dp)
                    .background(tint.copy(alpha = 0.12f), MaterialTheme.shapes.small),
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

private fun openUrl(context: android.content.Context, url: String) {
    runCatching {
        context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url)))
    }
}
