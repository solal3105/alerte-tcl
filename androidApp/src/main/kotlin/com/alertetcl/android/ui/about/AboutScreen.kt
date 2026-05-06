package com.alertetcl.android.ui.about

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.alertetcl.android.R
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

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
            .background(Color(0xFFF2F2F7)),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        item { HeroSection() }
        item { ManifestoCard() }
        item { OpenDataTribute() }
        item { SourcesCard() }
        item { CreatorCard() }
        item { ContactCard() }
        item { LinksFooter() }
        item { VersionFooter(versionName, versionCode) }
        item { Spacer(Modifier.height(20.dp)) }
    }
}

@Composable
private fun HeroSection() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Image(
            painter = painterResource(id = R.mipmap.ic_launcher),
            contentDescription = "App icon",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(96.dp)
                .clip(RoundedCornerShape(22.dp))
                .shadow(elevation = 8.dp, shape = RoundedCornerShape(22.dp))
        )
        Text("Lyon Pocket", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(
            "Les transports lyonnais, en direct.",
            fontSize = 14.sp,
            color = Color.Gray,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun ManifestoCard() = Card {
    Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Badge(Icons.Filled.CheckCircle, Color(0xFF43A047))
            Text("Respectueuse, par conception", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
        Text(
            "Lyon Pocket est gratuit, sans publicité, sans compte. Aucune donnée personnelle n'est collectée. C'est tout.",
            fontSize = 14.sp
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("Gratuit"); Pill("Sans pub"); Pill("Sans tracking")
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
                brush = Brush.linearGradient(
                    listOf(Color(0xFF0A8D4D), Color(0xFF0F6B8C))
                ),
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
private fun SourcesCard() = Card {
    Column {
        Row(
            modifier = Modifier.padding(start = 18.dp, end = 18.dp, top = 18.dp, bottom = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Badge(Icons.Filled.Wifi, Color(0xFF1E88E5))
            Text("Sources de données", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
        SourceRow("Position des véhicules", "SIRI-Lite, temps réel", Icons.Filled.LocationOn, Color(0xFF43A047))
        Sep()
        SourceRow("Arrêts, lignes, horaires", "GTFS", Icons.Filled.Tram, Color(0xFF3F51B5))
        Sep()
        SourceRow("Alertes & perturbations", "Flux officiel TCL", Icons.Filled.Warning, Color(0xFFFB8C00))
        Sep()
        SourceRow("Travaux", "Chantiers du réseau et de la voirie", Icons.Filled.Build, Color(0xFFFFC107))
        Sep()
        SourceRow("Parkings P+R", "Occupation en temps réel", Icons.Filled.DirectionsCar, Color(0xFF8E24AA))
        Text(
            "Toutes les données sont publiées par le Grand Lyon sous licence ouverte (Etalab / ODbL).",
            modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 14.dp),
            fontSize = 11.sp,
            color = Color.Gray
        )
    }
}

@Composable
private fun CreatorCard() = Card {
    Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Badge(Icons.Filled.Person, Color(0xFF3F51B5))
            Text("Derrière Lyon Pocket", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
        Text(
            "Solal Gendrin, conseiller métropolitain à Lyon. Lyon Pocket est un projet personnel, né d'un usage quotidien des TCL.",
            fontSize = 14.sp
        )
    }
}

@Composable
private fun ContactCard() {
    val context = LocalContext.current
    Card {
        Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Badge(Icons.Filled.Forum, Color(0xFFE91E63))
                Text("Une idée ? Un bug ?", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            }
            Text(
                "Suggestions, retours, propositions d'évolution : écrivez-moi sur LinkedIn, je lis tout.",
                fontSize = 14.sp
            )
            Surface(
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { openUrl(context, "https://www.linkedin.com/in/solal-gendrin/") },
                color = Color.Transparent
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            brush = Brush.horizontalGradient(listOf(Color(0xFF1976D2), Color(0xFF3F51B5))),
                            shape = RoundedCornerShape(12.dp)
                        )
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Send, null, tint = Color.White, modifier = Modifier.size(16.dp))
                        Text("Me contacter sur LinkedIn", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun LinksFooter() {
    val context = LocalContext.current
    Card {
        Column {
            FooterLink(
                "Site officiel", "lyon-pocket.netlify.app", Icons.Filled.Public, Color(0xFF26A69A)
            ) { openUrl(context, "https://lyon-pocket.netlify.app/") }
            Sep()
            FooterLink(
                "Politique de confidentialité", "Aucune donnée personnelle collectée",
                Icons.Filled.Lock, Color.Gray
            ) { openUrl(context, "https://solalgendrin.github.io/alerte-tcl/privacy") }
        }
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
            fontSize = 11.sp,
            color = Color.Gray
        )
        Text("Fait à Villeurbanne, avec ♥", fontSize = 10.sp, color = Color.LightGray)
    }
}

// ── helpers ────────────────────────────────────────────────────────────────

@Composable
private fun Card(content: @Composable () -> Unit) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = Color.White,
        modifier = Modifier.fillMaxWidth()
    ) { content() }
}

@Composable
private fun Sep() = HorizontalDivider(modifier = Modifier.padding(start = 60.dp), color = Color(0xFFE0E0E0))

@Composable
private fun Badge(icon: ImageVector, tint: Color) {
    Box(
        modifier = Modifier
            .size(30.dp)
            .background(tint.copy(alpha = 0.15f), RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center
    ) { Icon(icon, null, tint = tint, modifier = Modifier.size(14.dp)) }
}

@Composable
private fun Pill(text: String) {
    Surface(shape = RoundedCornerShape(50), color = Color(0xFFEEEEEE)) {
        Text(text, modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp), fontSize = 11.sp, color = Color.DarkGray)
    }
}

@Composable
private fun SourceRow(title: String, subtitle: String, icon: ImageVector, tint: Color) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(
            modifier = Modifier.size(36.dp).background(tint.copy(alpha = 0.15f), RoundedCornerShape(9.dp)),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = tint, modifier = Modifier.size(15.dp)) }
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.Medium)
            Text(subtitle, fontSize = 11.sp, color = Color.Gray)
        }
    }
}

@Composable
private fun FooterLink(title: String, subtitle: String, icon: ImageVector, tint: Color, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 18.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(
            modifier = Modifier.size(36.dp).background(tint.copy(alpha = 0.15f), RoundedCornerShape(9.dp)),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = tint, modifier = Modifier.size(15.dp)) }
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.Medium)
            Text(subtitle, fontSize = 11.sp, color = Color.Gray)
        }
        Icon(Icons.Outlined.OpenInNew, null, tint = Color.Gray, modifier = Modifier.size(14.dp))
    }
}

private fun openUrl(context: android.content.Context, url: String) {
    runCatching {
        context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url)))
    }
}
