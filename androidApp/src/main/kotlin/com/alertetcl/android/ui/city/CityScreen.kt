package com.alertetcl.android.ui.city

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.PedalBike
import androidx.compose.material.icons.filled.TwoWheeler
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.alertetcl.android.ui.components.GlassBackdrop
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.parking.ParkingScreen
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.android.ui.travaux.TravauxScreen
import com.alertetcl.shared.models.CityTile
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.util.DemoShowcase

/**
 * Onglet Ville : un accueil à tuiles (stationnement, Vélo'v, chantiers), puis la carte de la tuile
 * choisie avec une capsule de retour. En démo « velov… », la carte des stations s'ouvre directement.
 */
@Composable
fun CityScreen() {
    var chosenName by rememberSaveable {
        mutableStateOf(if (DemoShowcase.current?.startsWith("velov") == true) CityTile.VELOV.name else null)
    }
    val chosen = chosenName?.let { CityTile.valueOf(it) }
    if (chosen == null) {
        CityChooser(onChoose = { chosenName = it.name })
        return
    }
    Box(modifier = Modifier.fillMaxSize()) {
        val type = chosen.parkingType
        if (type == null) TravauxScreen() else ParkingScreen(type)
        CityHeader(
            tile = chosen,
            modifier = Modifier.align(Alignment.TopStart).statusBarsPadding().padding(start = 16.dp, top = 12.dp),
            onBack = { chosenName = null }
        )
    }
}

private fun tileIcon(tile: CityTile): ImageVector = when (tile.parkingType) {
    ParkingType.CAR          -> Icons.Filled.DirectionsCar
    ParkingType.VELOV        -> Icons.Filled.PedalBike
    ParkingType.BIKE         -> Icons.Filled.DirectionsBike
    ParkingType.MOTORIZED_2W -> Icons.Filled.TwoWheeler
    null                     -> Icons.Filled.Build
}

@Composable
private fun tileColor(tile: CityTile): Color = Tokens.cityTile(tile)

/** Accueil : une tuile en verre par entrée, les chantiers en pleine largeur, sur des taches de couleur floues. */
@Composable
private fun CityChooser(onChoose: (CityTile) -> Unit) {
    val tiles = CityTile.all
    Box(modifier = Modifier.fillMaxSize()) {
        GlassBackdrop(colors = tiles.map { tileColor(it) })
        Column(
            modifier = Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("Ville", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Choisissez ce que la carte doit afficher.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(4.dp))
            tiles.filter { it.parkingType != null }.chunked(2).forEach { row ->
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    row.forEach { tile -> CityTileCard(tile, Modifier.weight(1f)) { onChoose(tile) } }
                }
            }
            tiles.filter { it.parkingType == null }.forEach { tile ->
                CityTileCard(tile, Modifier.fillMaxWidth(), wide = true) { onChoose(tile) }
            }
            Spacer(Modifier.height(96.dp))
        }
    }
}

@Composable
private fun CityTileCard(tile: CityTile, modifier: Modifier, wide: Boolean = false, onClick: () -> Unit) {
    val accent = tileColor(tile)
    val shape = RoundedCornerShape(26.dp)
    Box(
        modifier = modifier
            .heightIn(min = if (wide) 96.dp else 168.dp)
            .glass(shape)
            .clickable { onClick() }
            .padding(18.dp)
    ) {
        if (wide) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                TileIcon(tile, accent)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(tile.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(tile.subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                TileIcon(tile, accent)
                Text(tile.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(tile.subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun TileIcon(tile: CityTile, accent: Color) {
    Box(
        modifier = Modifier.size(46.dp).glass(CircleShape, alpha = 0.35f),
        contentAlignment = Alignment.Center
    ) {
        Icon(tileIcon(tile), null, tint = accent, modifier = Modifier.size(24.dp))
    }
}

/** Capsule en verre en haut de la carte : la tuile affichée, un toucher ramène à l'accueil. */
@Composable
private fun CityHeader(tile: CityTile, modifier: Modifier, onBack: () -> Unit) {
    val accent = tileColor(tile)
    Row(
        modifier = modifier
            .glass(RoundedCornerShape(50), alpha = 0.78f)
            .clickable { onBack() }
            .padding(start = 10.dp, end = 16.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour à l'accueil de l'onglet Ville", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
        Box(modifier = Modifier.size(28.dp).glass(CircleShape, alpha = 0.35f), contentAlignment = Alignment.Center) {
            Icon(tileIcon(tile), null, tint = accent, modifier = Modifier.size(16.dp))
        }
        Text(tile.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
    }
}
