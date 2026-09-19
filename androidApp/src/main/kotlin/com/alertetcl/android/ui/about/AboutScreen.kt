package com.alertetcl.android.ui.about

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocationCity
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Park
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.openUrl
import com.alertetcl.android.ui.theme.Tokens

/**
 * Onglet Info : Solal Gendrin, son mandat, ses projets, comment le joindre, puis les remerciements
 * et les sources. Une seule teinte d'interface (l'accent), le vert pour son étiquette d'élu écologiste.
 */
@Composable
fun AboutScreen() {
    val context = LocalContext.current
    val pm = context.packageManager
    val versionName = runCatching { pm.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "1.0"
    val versionCode = runCatching { pm.getPackageInfo(context.packageName, 0).longVersionCode }.getOrNull()?.toString() ?: ""

    LazyColumn(
        modifier = Modifier.fillMaxSize().statusBarsPadding().background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        item { Hero() }
        item { AboutSection("À la Métropole") { MandateCard() } }
        item { AboutSection("Mes projets") { ProjectsCard() } }
        item { AboutSection("On se parle ?") { ContactCard() } }
        item { AboutSection("Merci") { OpenDataCard() } }
        item { AboutSection("D'où viennent les données") { SourcesCard() } }
        item { Footer(versionName, versionCode) }
    }
}

@Composable
private fun Hero() {
    Column(modifier = Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Box(modifier = Modifier.size(72.dp).background(Tokens.success, CircleShape), contentAlignment = Alignment.Center) {
                Text("SG", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Solal Gendrin", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Text("Conseiller métropolitain écologiste", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = Tokens.success)
                Text("Élu de Villeurbanne, mandat 2026 à 2032", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Text(
            "Bonjour, moi c'est Solal. Je siège à la Métropole de Lyon pour Villeurbanne, dans le groupe des écologistes. Le reste du temps, je construis des outils pour rendre la ville plus lisible. Lyon Pocket est né un soir, quand TCL Live a disparu et que je voulais simplement retrouver mon bus sur une carte. Depuis, plus de 25 000 personnes l'ont installée, et l'app a même passé quelques jours en tête des applications de navigation sur l'App Store, devant Google Maps et Waze.",
            style = MaterialTheme.typography.bodyMedium,
            lineHeight = 21.sp
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill("Gratuite"); Pill("Sans pub"); Pill("Sans compte"); Pill("Sans données vendues")
        }
    }
}

@Composable
private fun MandateCard() {
    AboutCard {
        InfoRow(Icons.Filled.Home, "Habitat et logement", "Renouvellement urbain et politique de la ville")
        RowDivider()
        InfoRow(Icons.Filled.AccountBalance, "Grands projets et rayonnement", "Tourisme et relations internationales")
        RowDivider()
        InfoRow(Icons.Filled.Park, "Espace public", "Territoires, propreté urbaine et qualité de l'espace public")
    }
}

@Composable
private fun ProjectsCard() {
    val context = LocalContext.current
    AboutCard {
        ProjectRow(Icons.Filled.Tram, "Lyon Pocket",
            "Cette application : les bus et les trams en direct, les alertes, les fiches horaires, les chantiers, les parkings et les Vélo'v.") {
            openUrl(context, "https://lyon-pocket.netlify.app/")
        }
        RowDivider()
        ProjectRow(Icons.Filled.SportsEsports, "TCL 2040",
            "Mettez-vous à la place du président du Sytral : un budget fermé, des projets réels, des impacts chiffrés. Dessinez le réseau de 2040 et voyez ce qu'il coûte vraiment.") {
            openUrl(context, "https://tcl-2040.com/")
        }
        RowDivider()
        ProjectRow(Icons.Filled.Map, "Grands Projets",
            "La carte des projets urbains et de mobilité autour de vous, avec leur avancement, leur calendrier et les documents officiels.") {
            openUrl(context, "https://grandsprojets.com/")
        }
        RowDivider()
        ProjectRow(Icons.Filled.LocationCity, "Open Projets, avec Vazy",
            "La même idée, offerte aux communes : la carte de leurs chantiers et de leurs projets, que les habitants consultent sans compte. Construite chez Vazy, société à mission villeurbannaise, où je dirige le produit et la technique.") {
            openUrl(context, "https://openprojets.com/home")
        }
        RowDivider()
        ProjectRow(Icons.Filled.Air, "Nadir",
            "Rafraîchir son logement sans climatisation : l'app compare heure par heure la température chez vous et dehors, et vous dit quand ouvrir et fermer les fenêtres.") {
            openUrl(context, "https://apps.apple.com/fr/app/nadir/id6788036137")
        }
    }
}

@Composable
private fun ContactCard() {
    val context = LocalContext.current
    AboutCard {
        LinkRow(Icons.Filled.Person, "LinkedIn", "Pour me suivre et m'écrire, je lis tout") { openUrl(context, "https://www.linkedin.com/in/solal-gendrin/") }
        RowDivider()
        LinkRow(Icons.Filled.ChatBubble, "X", "@_solal_") { openUrl(context, "https://x.com/_solal_") }
        RowDivider()
        LinkRow(Icons.Filled.Code, "GitHub", "solal3105") { openUrl(context, "https://github.com/solal3105") }
    }
}

@Composable
private fun OpenDataCard() {
    val context = LocalContext.current
    AboutCard {
        Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "Rien de tout ça n'existerait sans les équipes Open Data du Grand Lyon, qui publient les positions des bus, les alertes, les chantiers, les parkings et les Vélo'v sous licence ouverte. C'est un travail discret qui rend possibles des projets citoyens comme celui-ci.",
                style = MaterialTheme.typography.bodyMedium,
                lineHeight = 21.sp
            )
            Row(
                modifier = Modifier.clickable { openUrl(context, "https://data.grandlyon.com") },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text("data.grandlyon.com", color = Tokens.accent, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
                Icon(Icons.Outlined.OpenInNew, null, tint = Tokens.accent, modifier = Modifier.size(14.dp))
            }
        }
    }
}

@Composable
private fun SourcesCard() {
    AboutCard {
        InfoRow(Icons.Filled.LocationOn, "Position des véhicules", "SIRI-Lite, en direct")
        RowDivider()
        InfoRow(Icons.Filled.Tram, "Arrêts, lignes, horaires", "GTFS")
        RowDivider()
        InfoRow(Icons.Filled.Warning, "Alertes et perturbations", "Flux officiel TCL")
        RowDivider()
        InfoRow(Icons.Filled.Build, "Travaux", "Chantiers du réseau et de la voirie")
        RowDivider()
        InfoRow(Icons.Filled.DirectionsCar, "Parkings et Vélo'v", "Disponibilité en direct")
        Text(
            "Toutes ces données sont publiées par le Grand Lyon sous licence ouverte (Etalab / ODbL).",
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 14.dp),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun Footer(version: String, build: String) {
    val context = LocalContext.current
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            "Politique de confidentialité",
            color = Tokens.accent, fontWeight = FontWeight.Medium, style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.clickable { openUrl(context, "https://lyon-pocket.netlify.app/privacy") }
        )
        Text(
            "Lyon Pocket $version" + (if (build.isNotEmpty()) " ($build)" else "") + " · Fait à Villeurbanne",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            "Application indépendante, sans lien avec SYTRAL Mobilités, Keolis Lyon ou TCL.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.outline,
            textAlign = TextAlign.Center
        )
    }
}

// ── Composants ──────────────────────────────────────────────────────

@Composable
private fun AboutSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            title.uppercase(),
            style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 4.dp)
        )
        content()
    }
}

@Composable
private fun AboutCard(content: @Composable () -> Unit) {
    Surface(shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), modifier = Modifier.fillMaxWidth()) {
        Column { content() }
    }
}

@Composable
private fun RowDivider() {
    HorizontalDivider(modifier = Modifier.padding(start = 62.dp))
}

@Composable
private fun IconBox(icon: ImageVector) {
    Box(
        modifier = Modifier.size(34.dp).background(Tokens.accent.copy(alpha = 0.12f), RoundedCornerShape(9.dp)),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = Tokens.accent, modifier = Modifier.size(17.dp))
    }
}

@Composable
private fun Pill(text: String) {
    Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)) {
        Text(
            text, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
        )
    }
}

@Composable
private fun InfoRow(icon: ImageVector, title: String, subtitle: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        IconBox(icon)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ProjectRow(icon: ImageVector, title: String, text: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        IconBox(icon)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                Icon(Icons.Outlined.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(12.dp))
            }
            Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, lineHeight = 18.sp)
        }
    }
}

@Composable
private fun LinkRow(icon: ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        IconBox(icon)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.width(4.dp))
        Icon(Icons.Outlined.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp))
    }
}
