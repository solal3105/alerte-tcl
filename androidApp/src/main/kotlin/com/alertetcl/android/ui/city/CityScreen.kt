package com.alertetcl.android.ui.city

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.map.mapStyleBuilder
import com.alertetcl.android.ui.map.recenterOnUser
import com.alertetcl.android.ui.map.rememberManagedMapView
import com.alertetcl.android.ui.parking.ParkingScreen
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.android.ui.travaux.TravauxScreen
import com.alertetcl.shared.models.CityTile
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.util.DemoShowcase
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng

/**
 * Onglet « Autour de moi » : un accueil à tuiles de verre posées sur une carte immobile (stationnement,
 * Vélo'v, chantiers, avec leurs chiffres en direct), puis la carte de la tuile choisie sous une capsule
 * de retour ; le geste retour du système ramène aussi à l'accueil. En démo « velov… », la carte des
 * stations s'ouvre directement.
 */
@Composable
fun CityScreen() {
    var chosenName by rememberSaveable {
        mutableStateOf(if (DemoShowcase.current?.startsWith("velov") == true) CityTile.VELOV.name else null)
    }
    val chosen = chosenName?.let { CityTile.valueOf(it) }
    BackHandler(enabled = chosen != null) { chosenName = null }
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

/** Accueil : la carte de la ville, immobile, sous un voile ; les tuiles de verre par-dessus. */
@Composable
private fun CityChooser(onChoose: (CityTile) -> Unit) {
    val tiles = CityTile.all
    Box(modifier = Modifier.fillMaxSize()) {
        MapBackdrop()
        val background = MaterialTheme.colorScheme.background
        Box(
            modifier = Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(background.copy(alpha = 0.45f), background.copy(alpha = 0.92f)))
            )
        )
        Column(
            modifier = Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("Autour de moi", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
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

/** Carte MapLibre sans interaction, centrée sur la position si elle est connue, sinon sur Lyon. */
@Composable
private fun MapBackdrop() {
    val context = LocalContext.current
    val isDark = isSystemInDarkTheme()
    val mapView = rememberManagedMapView()
    AndroidView(
        factory = {
            mapView.also { mv ->
                mv.getMapAsync { map ->
                    map.uiSettings.setAllGesturesEnabled(false)
                    map.uiSettings.isLogoEnabled = false
                    map.uiSettings.isAttributionEnabled = false
                    map.uiSettings.isCompassEnabled = false
                    map.cameraPosition = CameraPosition.Builder().target(LatLng(45.7578, 4.8320)).zoom(14.0).build()
                    map.setStyle(mapStyleBuilder(isSatellite = false, isDark = isDark)) { recenterOnUser(context, map) }
                }
            }
        },
        modifier = Modifier.fillMaxSize()
    )
}

@Composable
private fun CityTileCard(tile: CityTile, modifier: Modifier, wide: Boolean = false, onClick: () -> Unit) {
    val accent = tileColor(tile)
    val shape = RoundedCornerShape(28.dp)
    Box(
        modifier = modifier
            .heightIn(min = if (wide) 96.dp else 172.dp)
            .glass(shape, alpha = 0.86f)
            .background(accent.copy(alpha = 0.14f))
            .clickable { onClick() }
            .padding(18.dp)
    ) {
        if (wide) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                TileIcon(tile, accent)
                TileTexts(tile)
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                TileIcon(tile, accent)
                TileTexts(tile)
            }
        }
    }
}

@Composable
private fun TileTexts(tile: CityTile) {
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Text(tile.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Text(tile.subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Pictogramme blanc sur un disque plein à la couleur de la tuile. */
@Composable
private fun TileIcon(tile: CityTile, accent: Color, size: Int = 52, iconSize: Int = 26) {
    Box(
        modifier = Modifier.size(size.dp).background(accent, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Icon(tileIcon(tile), null, tint = Color.White, modifier = Modifier.size(iconSize.dp))
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
        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour à l'accueil", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
        TileIcon(tile, accent, size = 28, iconSize = 16)
        Text(tile.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
    }
}
