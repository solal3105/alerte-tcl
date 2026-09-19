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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.LocationCity
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.VisibilityOff
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.R
import com.alertetcl.android.ui.openUrl
import com.alertetcl.android.ui.theme.Tokens

/**
 * Onglet Info : l'application d'abord (icône, nom, accroche, quatre promesses), puis qui est
 * derrière, ses autres projets avec leurs logos, d'où viennent les données. Une seule teinte
 * d'interface (l'accent), le vert réservé à l'étiquette d'élu écologiste.
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
        item { Author() }
        item { Projects() }
        item { DataSources() }
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
            "Les bus et les trams en direct sur la carte, les alertes de vos lignes, les fiches horaires, les chantiers, les parkings et les Vélo'v. Tout Lyon dans la poche.",
            fontSize = 18.sp, lineHeight = 27.sp
        )
    }
}

@Composable
private fun Promises() {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Promise(Icons.Filled.CardGiftcard, "Gratuite", Modifier.weight(1f))
            Promise(Icons.Filled.VisibilityOff, "Sans publicité", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Promise(Icons.Filled.PersonOff, "Sans compte", Modifier.weight(1f))
            Promise(Icons.Filled.Lock, "Sans traçage", Modifier.weight(1f))
        }
    }
}

@Composable
private fun Promise(icon: ImageVector, title: String, modifier: Modifier) {
    Card(modifier) {
        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            AccentIcon(icon, 36, 18)
            Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
        }
    }
}

@Composable
private fun Author() {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionTitle("Qui est derrière")
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
                LinkRow(Icons.Filled.Person, "LinkedIn", "Retours, idées, bugs : je lis tout") { openUrl(context, "https://www.linkedin.com/in/solal-gendrin/") }
                HorizontalDivider(modifier = Modifier.padding(start = 66.dp))
                LinkRow(Icons.Filled.ChatBubble, "X", "@_solal_") { openUrl(context, "https://x.com/_solal_") }
            }
        }
    }
}

@Composable
private fun Projects() {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionTitle("Ses autres projets")
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Project(R.drawable.logo_tcl2040, logoOnAccent = true, logoPadding = 10, title = "TCL 2040",
                text = "Prenez la place du président du Sytral : un budget fermé, des projets réels, des impacts chiffrés. Dessinez le réseau de 2040 et voyez ce qu'il coûte vraiment.") {
                openUrl(context, "https://tcl-2040.com/")
            }
            Project(R.drawable.logo_openprojets, logoOnAccent = true, logoPadding = 9, title = "Open Projets",
                text = "Née « Grands Projets » pour la Métropole, devenue la carte que chaque commune peut ouvrir à ses habitants : chantiers, projets, avancement, documents. Construite chez Vazy, société à mission villeurbannaise.") {
                openUrl(context, "https://openprojets.com/home")
            }
            Project(R.drawable.logo_nadir, logoOnAccent = false, logoPadding = 0, title = "Nadir",
                text = "Rafraîchir son logement sans climatisation : l'app compare heure par heure la température chez vous et dehors, et vous dit quand ouvrir et fermer les fenêtres.") {
                openUrl(context, "https://apps.apple.com/fr/app/nadir/id6788036137")
            }
        }
    }
}

@Composable
private fun Project(logo: Int, logoOnAccent: Boolean, logoPadding: Int, title: String, text: String, onClick: () -> Unit) {
    Card(Modifier.fillMaxWidth().clickable { onClick() }) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(
                modifier = Modifier.size(60.dp).clip(RoundedCornerShape(14.dp))
                    .background(if (logoOnAccent) Tokens.accent else Color.Transparent),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    painter = painterResource(id = logo), contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize().padding(logoPadding.dp)
                )
            }
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(title, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                    Icon(Icons.Outlined.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(12.dp))
                }
                Text(text, style = MaterialTheme.typography.bodySmall, lineHeight = 18.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun DataSources() {
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionTitle("D'où viennent les données")
        Card(Modifier.fillMaxWidth()) {
            Column {
                DataRow(Icons.Filled.LocationCity, "Métropole de Lyon",
                    "Positions des bus et des trams, alertes, chantiers, parkings et Vélo'v, publiés en données ouvertes sur data.grandlyon.com.") {
                    openUrl(context, "https://data.grandlyon.com")
                }
                HorizontalDivider(modifier = Modifier.padding(start = 66.dp))
                DataRow(Icons.Filled.Tram, "SYTRAL Mobilités", "Arrêts, tracés et horaires des lignes TCL, au format GTFS.", onClick = null)
                HorizontalDivider(modifier = Modifier.padding(start = 18.dp))
                Text(
                    "Merci aux équipes qui publient tout ça librement. Lyon Pocket est une application indépendante, sans lien avec SYTRAL Mobilités, Keolis Lyon ou TCL.",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(18.dp)
                )
            }
        }
    }
}

@Composable
private fun DataRow(icon: ImageVector, title: String, text: String, onClick: (() -> Unit)?) {
    Row(
        modifier = Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable { onClick() } else Modifier).padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        AccentIcon(icon, 38, 18)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                if (onClick != null) Icon(Icons.Outlined.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(12.dp))
            }
            Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Footer(version: String) {
    val context = LocalContext.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            "Politique de confidentialité",
            color = Tokens.accent, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.clickable { openUrl(context, "https://lyon-pocket.netlify.app/privacy") }
        )
        Text("Version $version, faite à Villeurbanne", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ── Composants ──────────────────────────────────────────────────────

@Composable
private fun SectionTitle(text: String) {
    Text(text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
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

@Composable
private fun LinkRow(icon: ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
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
        Spacer(Modifier.width(4.dp))
        Icon(Icons.Outlined.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(14.dp))
    }
}
