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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.VisibilityOff
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.R
import com.alertetcl.android.ui.openUrl
import com.alertetcl.android.ui.theme.Tokens

/**
 * Onglet Info : une page éditoriale sur Lyon Pocket, puis sur celui qui la fait. L'application en
 * tête (icône, nom, accroche, quatre promesses, deux chiffres), « Qui est derrière » (Solal Gendrin,
 * ses contacts), ses autres projets, un remerciement, les sources. Une seule teinte d'interface
 * (l'accent), le vert réservé à l'étiquette d'élu écologiste.
 */
@Composable
fun AboutScreen() {
    val context = LocalContext.current
    val versionName = runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "1.0"

    LazyColumn(
        modifier = Modifier.fillMaxSize().statusBarsPadding().background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 28.dp, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(36.dp)
    ) {
        item { Hero() }
        item { Promises() }
        item { Numbers() }
        item { Author() }
        item { Projects() }
        item { Thanks() }
        item { Sources() }
        item { Footer(versionName) }
    }
}

@Composable
private fun Hero() {
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Image(
            painter = painterResource(id = R.mipmap.ic_launcher),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(76.dp).clip(RoundedCornerShape(18.dp))
        )
        Text("Lyon Pocket", fontSize = 38.sp, lineHeight = 42.sp, fontWeight = FontWeight.Bold)
        Text(
            "Les bus et les trams en direct sur la carte, les alertes de vos lignes, les fiches horaires, les chantiers, les parkings et les Vélo'v. Tout Lyon dans la poche, sans compte et sans publicité.",
            fontSize = 18.sp, lineHeight = 27.sp
        )
    }
}

@Composable
private fun Author() {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Eyebrow("Qui est derrière")
        Card(Modifier.fillMaxWidth()) {
            Column {
                Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        "CONSEILLER MÉTROPOLITAIN ÉCOLOGISTE · VILLEURBANNE",
                        style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, letterSpacing = 0.5.sp, color = Tokens.success
                    )
                    Text("Solal Gendrin", fontSize = 26.sp, fontWeight = FontWeight.Bold)
                    Text(
                        "Je siège à la Métropole de Lyon pour Villeurbanne, chez les écologistes. Le soir, je code des outils pour rendre la ville plus lisible. Lyon Pocket est né comme ça, quand TCL Live a disparu : je voulais retrouver mon bus sur une carte. Vous êtes maintenant des milliers à l'utiliser, et ça me fait toujours quelque chose.",
                        fontSize = 16.sp, lineHeight = 24.sp
                    )
                }
                HorizontalDivider(modifier = Modifier.padding(start = 18.dp))
                ContactRow(Icons.Filled.Person, "LinkedIn", "Retours, idées, bugs : je lis tout") { openUrl(context, "https://www.linkedin.com/in/solal-gendrin/") }
                HorizontalDivider(modifier = Modifier.padding(start = 66.dp))
                ContactRow(Icons.Filled.ChatBubble, "X", "@_solal_") { openUrl(context, "https://x.com/_solal_") }
            }
        }
    }
}

@Composable
private fun Promises() {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Eyebrow("Lyon Pocket, c'est")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Promise(Icons.Filled.CardGiftcard, "Gratuite", "Pour tout le monde, pour toujours.", Modifier.weight(1f))
            Promise(Icons.Filled.VisibilityOff, "Sans publicité", "Rien ne s'affiche entre vous et votre bus.", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Promise(Icons.Filled.PersonOff, "Sans compte", "On ouvre, ça marche.", Modifier.weight(1f))
            Promise(Icons.Filled.Lock, "Sans traçage", "Aucune donnée collectée, donc rien à vendre.", Modifier.weight(1f))
        }
    }
}

@Composable
private fun Promise(icon: ImageVector, title: String, text: String, modifier: Modifier) {
    Card(modifier.heightIn(min = 128.dp)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(icon, null, tint = Tokens.accent, modifier = Modifier.size(24.dp))
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Numbers() {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Number("25 000", "installations, et ça continue", Modifier.weight(1f))
        Number("N° 1", "des apps de navigation sur le Play Store et l'App Store, un temps devant Google Maps et Waze", Modifier.weight(1f))
    }
}

@Composable
private fun Number(value: String, caption: String, modifier: Modifier) {
    Card(modifier.heightIn(min = 118.dp)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(value, fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Tokens.accent, maxLines = 1)
            Text(caption, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Projects() {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Eyebrow("Ses autres projets")
        Project("TCL 2040", "Prenez la place du président du Sytral : un budget fermé, des projets réels, des impacts chiffrés. Dessinez le réseau de 2040 et voyez ce qu'il coûte vraiment.") {
            openUrl(context, "https://tcl-2040.com/")
        }
        Project("Open Projets", "Née « Grands Projets » pour la Métropole, devenue la carte que chaque commune peut ouvrir à ses habitants : chantiers, projets, avancement, documents. Je la construis chez Vazy, société à mission villeurbannaise.") {
            openUrl(context, "https://openprojets.com/home")
        }
        Project("Nadir", "Rafraîchir son logement sans climatisation : l'app compare heure par heure la température chez vous et dehors, et vous dit quand ouvrir et fermer les fenêtres.") {
            openUrl(context, "https://apps.apple.com/fr/app/nadir/id6788036137")
        }
    }
}

@Composable
private fun Project(title: String, text: String, onClick: () -> Unit) {
    Card(Modifier.fillMaxWidth().clickable { onClick() }) {
        Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Icon(Icons.Outlined.OpenInNew, null, tint = Tokens.accent, modifier = Modifier.size(16.dp))
            }
            Text(text, style = MaterialTheme.typography.bodyMedium, lineHeight = 20.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ContactRow(icon: ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        AccentIcon(icon, 38, 18)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Icon(Icons.Outlined.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(14.dp))
    }
}

@Composable
private fun Thanks() {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Eyebrow("Merci")
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Box(modifier = Modifier.width(3.dp).height(150.dp).background(Tokens.accent, RoundedCornerShape(2.dp)))
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    "Rien de tout ça n'existerait sans les équipes Open Data du Grand Lyon, qui publient les positions des bus, les alertes, les chantiers, les parkings et les Vélo'v sous licence ouverte. Un travail discret, qui rend possibles des projets citoyens comme celui-ci.",
                    fontSize = 16.sp, lineHeight = 24.sp
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
}

@Composable
private fun Sources() {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Eyebrow("D'où viennent les données")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Source(Icons.Filled.LocationOn, "Positions des bus et trams", "SIRI-Lite, en direct", Modifier.weight(1f))
            Source(Icons.Filled.Tram, "Arrêts, lignes, horaires", "GTFS", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Source(Icons.Filled.Warning, "Alertes trafic", "Flux officiel TCL", Modifier.weight(1f))
            Source(Icons.Filled.Build, "Travaux", "Réseau et voirie", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Source(Icons.Filled.DirectionsCar, "Parkings", "Places libres en direct", Modifier.weight(1f))
            Source(Icons.Filled.DirectionsBike, "Vélo'v", "Vélos et places en direct", Modifier.weight(1f))
        }
        Text(
            "Toutes ces données sont publiées par le Grand Lyon sous licence ouverte (Etalab et ODbL).",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun Source(icon: ImageVector, title: String, detail: String, modifier: Modifier) {
    Card(modifier.heightIn(min = 74.dp)) {
        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            AccentIcon(icon, 30, 16)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                Text(detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun Footer(version: String) {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "Politique de confidentialité",
            color = Tokens.accent, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.clickable { openUrl(context, "https://lyon-pocket.netlify.app/privacy") }
        )
        Text(
            "Lyon Pocket $version, fait à Villeurbanne. Application indépendante, sans lien avec SYTRAL Mobilités, Keolis Lyon ou TCL.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

// ── Composants ──────────────────────────────────────────────────────

@Composable
private fun Eyebrow(text: String) {
    Text(
        text.uppercase(),
        style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, letterSpacing = 0.6.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun Card(modifier: Modifier, content: @Composable () -> Unit) {
    Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), modifier = modifier) {
        content()
    }
}

@Composable
private fun AccentIcon(icon: ImageVector, size: Int, iconSize: Int) {
    Box(
        modifier = Modifier.size(size.dp).background(Tokens.accent.copy(alpha = 0.12f), RoundedCornerShape((size * 0.29f).dp)),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = Tokens.accent, modifier = Modifier.size(iconSize.dp))
    }
}
