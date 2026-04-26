package com.alertetcl.android.ui.parking

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.PointF
import android.location.LocationManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.TwoWheeler
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
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
import androidx.compose.ui.viewinterop.AndroidView
import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.geo.LatLng as GeoLatLng
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.viewmodels.ParkingViewModel
import com.google.gson.JsonObject
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.Point
import kotlin.math.pow

private const val STYLE_URL     = "https://tiles.openfreemap.org/styles/liberty"
private const val STYLE_JSON_SATELLITE = """{
  "version": 8,
  "sources": {
    "satellite": {
      "type": "raster",
      "tiles": ["https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"],
      "tileSize": 256,
      "attribution": "Tiles © Esri"
    }
  },
  "layers": [{"id": "satellite", "type": "raster", "source": "satellite"}]
}"""
private const val PARKING_SRC   = "parking-src"
private const val PARKING_LAYER = "parking-layer"

@Composable
private fun rememberParkingMapView(): MapView {
    val context = LocalContext.current
    val mapView = remember { MapView(context) }
    DisposableEffect(Unit) {
        mapView.onCreate(null)
        mapView.onStart()
        mapView.onResume()
        onDispose { mapView.onPause(); mapView.onStop(); mapView.onDestroy() }
    }
    return mapView
}

@OptIn(ExperimentalMaterial3Api::class, kotlinx.coroutines.FlowPreview::class)
@Composable
fun ParkingScreen() {
    val vm = remember { ParkingViewModel() }
    val context = LocalContext.current
    DisposableEffect(Unit) { onDispose { vm.dispose() } }

    val parkings by vm.parkings.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val showParcRelais by vm.showParcRelais.collectAsState()
    val showRealtimeParkings by vm.showRealtimeParkings.collectAsState()
    val isLoading by vm.isLoading.collectAsState()
    val lastUpdateMs by vm.lastUpdateEpochMs.collectAsState()

    var mapLibreMap by remember { mutableStateOf<MapLibreMap?>(null) }
    var mapStyle by remember { mutableStateOf<Style?>(null) }
    var isSatellite by remember { mutableStateOf(false) }

    val parkingsRef = remember { mutableStateOf<List<Parking>>(emptyList()) }
    parkingsRef.value = parkings

    var selectedParking by remember { mutableStateOf<Parking?>(null) }
    var showFilterSheet by remember { mutableStateOf(false) }
    val showCarFilters = ParkingType.CAR in selectedTypes
    val currentRegion = remember { mutableStateOf<GeoRegion?>(null) }

    // Tick 1s pour rafraîchir le label "il y a Xs" du refresh card
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) { kotlinx.coroutines.delay(1000); nowMs = System.currentTimeMillis() }
    }

    val locationPermLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) recenterParkingOnUser(context, mapLibreMap) }

    val mapView = rememberParkingMapView()

    Box(modifier = Modifier.fillMaxSize()) {
        AndroidView(
            factory = { _ ->
                mapView.also { mv ->
                    mv.getMapAsync { map ->
                        mapLibreMap = map
                        map.uiSettings.isLogoEnabled = false
                        map.uiSettings.isAttributionEnabled = false
                        map.cameraPosition = CameraPosition.Builder()
                            .target(LatLng(45.764043, 4.835659))
                            .zoom(13.0)
                            .build()
                        map.addOnCameraIdleListener {
                            val cam = map.cameraPosition
                            val zoom = cam.zoom
                            val target = cam.target
                            if (target != null) {
                                val deltaLat = 0.6 / 2.0.pow(zoom - 8.0)
                                val region = GeoRegion(
                                    center = GeoLatLng(target.latitude, target.longitude),
                                    latitudeDelta = deltaLat, longitudeDelta = deltaLat
                                )
                                currentRegion.value = region
                                vm.loadInRegion(region)
                            }
                        }
                        map.addOnMapClickListener { latLng ->
                            val screen = map.projection.toScreenLocation(latLng)
                            val hits = map.queryRenderedFeatures(PointF(screen.x, screen.y), PARKING_LAYER)
                            if (hits.isNotEmpty()) {
                                val id = hits[0].getStringProperty("id")
                                selectedParking = parkingsRef.value.find { it.id == id }
                                true
                            } else false
                        }
                        map.setStyle(STYLE_URL) { style -> mapStyle = style }
                    }
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Switch base style on satellite toggle
        LaunchedEffect(isSatellite) {
            val map = mapLibreMap ?: return@LaunchedEffect
            val builder = if (isSatellite) Style.Builder().fromJson(STYLE_JSON_SATELLITE)
                          else              Style.Builder().fromUri(STYLE_URL)
            mapStyle = null
            map.setStyle(builder) { style -> mapStyle = style }
            // Re-trigger parking load to recreate marker layer on new style
            currentRegion.value?.let { vm.loadInRegion(it) }
        }

        // Selector top-center (translucide pour ne pas masquer la carte) + indicator de chargement
        Column(modifier = Modifier.fillMaxWidth().padding(8.dp)) {
            if (isLoading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            Row(
                modifier = Modifier.padding(top = 8.dp).align(Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(50),
                    color = Color.White.copy(alpha = 0.85f),
                    tonalElevation = 4.dp,
                    shadowElevation = 4.dp
                ) {
                    Row(modifier = Modifier.padding(4.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        ParkingType.entries.forEach { type ->
                            ParkingTypeButton(
                                type = type,
                                isSelected = type in selectedTypes,
                                onClick = { vm.toggleType(type) }
                            )
                        }
                    }
                }
            }
        }

        // Bottom-right FABs (parité iOS) : satellite, filters (only car), location
        Column(
            modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            ParkingCircleFab(
                icon = Icons.Filled.Public, contentDesc = "Vue satellite",
                tint = if (isSatellite) Color(0xFFFF9500) else Color(0xFF1C1C1E),
                onClick = { isSatellite = !isSatellite }
            )
            if (showCarFilters) {
                val hasActiveFilters = !showParcRelais || !showRealtimeParkings
                ParkingCircleFab(
                    icon = Icons.Filled.FilterList, contentDesc = "Filtres",
                    tint = if (hasActiveFilters) Color(0xFFFF9500) else Color(0xFF1C1C1E),
                    onClick = { showFilterSheet = true }
                )
            }
            ParkingCircleFab(
                icon = Icons.Filled.MyLocation, contentDesc = "Ma position",
                tint = Color(0xFF007AFF),
                onClick = {
                    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
                        context, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) recenterParkingOnUser(context, mapLibreMap)
                    else locationPermLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                }
            )
        }

        // Refresh card bottom-left for car type (avec timestamp)
        if (showCarFilters) {
            Surface(
                shape = RoundedCornerShape(50),
                color = Color.White.copy(alpha = 0.95f),
                tonalElevation = 6.dp,
                shadowElevation = 6.dp,
                modifier = Modifier.align(Alignment.BottomStart).padding(16.dp)
                    .clickable { currentRegion.value?.let { vm.loadInRegion(it, forceRefresh = true) } }
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(Icons.Filled.Refresh, "Rafraîchir", tint = Color(0xFF007AFF), modifier = Modifier.size(18.dp))
                    val txt = lastUpdateMs?.let {
                        val s = (nowMs - it) / 1000L
                        when {
                            s < 5 -> "à l'instant"
                            s < 60 -> "il y a ${s}s"
                            else -> "il y a ${s / 60}min"
                        }
                    } ?: "Rafraîchir"
                    Text(txt, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                }
            }
        }
    }

    if (showFilterSheet) {
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            sheetState = rememberModalBottomSheetState()
        ) {
            ParkingFilterSheet(
                showParcRelais = showParcRelais,
                onToggleParcRelais = { vm.toggleParcRelais() },
                showRealtimeParkings = showRealtimeParkings,
                onToggleRealtime = { vm.toggleRealtimeParkings() }
            )
        }
    }

    selectedParking?.let { p ->
        ModalBottomSheet(
            onDismissRequest = { selectedParking = null },
            sheetState = rememberModalBottomSheetState()
        ) { ParkingDetailSheet(p) }
    }

    // Update parking markers
    LaunchedEffect(mapStyle, parkings) {
        val style = mapStyle ?: return@LaunchedEffect
        AvailabilityColor.entries.forEach { color ->
            listOf(false, true).forEach { pr ->
                val iconId = parkingIconId(color, pr)
                if (style.getImage(iconId) == null) style.addImage(iconId, parkingMarkerBitmap(color, pr))
            }
        }
        val features = parkings.map { p ->
            val props = JsonObject().apply {
                addProperty("id", p.id)
                addProperty("icon", parkingIconId(p.availabilityColor, p.isParcRelais))
            }
            Feature.fromGeometry(Point.fromLngLat(p.longitude, p.latitude), props)
        }
        if (style.getSource(PARKING_SRC) == null) {
            style.addSource(GeoJsonSource(PARKING_SRC, FeatureCollection.fromFeatures(features)))
            style.addLayer(SymbolLayer(PARKING_LAYER, PARKING_SRC).withProperties(
                PropertyFactory.iconImage(Expression.get("icon")),
                PropertyFactory.iconAllowOverlap(true),
                PropertyFactory.iconIgnorePlacement(true),
                PropertyFactory.iconSize(1f)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(PARKING_SRC)?.setGeoJson(FeatureCollection.fromFeatures(features))
        }
    }
}

@Composable
private fun ParkingCircleFab(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDesc: String, tint: Color, onClick: () -> Unit
) {
    Surface(
        shape = CircleShape, color = Color.White.copy(alpha = 0.95f),
        tonalElevation = 6.dp, shadowElevation = 6.dp,
        modifier = Modifier.size(50.dp)
    ) {
        IconButton(onClick = onClick, modifier = Modifier.fillMaxSize()) {
            Icon(icon, contentDesc, tint = tint, modifier = Modifier.size(22.dp))
        }
    }
}

private fun recenterParkingOnUser(context: android.content.Context, map: MapLibreMap?) {
    val m = map ?: return
    val lm = context.getSystemService(android.content.Context.LOCATION_SERVICE) as? LocationManager ?: return
    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
        context, Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    if (!granted) return
    @Suppress("MissingPermission")
    val loc = listOfNotNull(
        runCatching { lm.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull(),
        runCatching { lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull()
    ).maxByOrNull { it.time } ?: return
    m.animateCamera(
        CameraUpdateFactory.newCameraPosition(
            CameraPosition.Builder().target(LatLng(loc.latitude, loc.longitude)).zoom(15.0).build()
        )
    )
}

@Composable
private fun ParkingDetailSheet(p: Parking) {
    Column(modifier = Modifier.padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .width(12.dp)
                    .height(12.dp)
                    .padding(end = 0.dp),
            )
            Text(p.nom, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        Text(p.adresse, fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(10.dp))
        if (p.isParcRelais) {
            Text("Parc Relais (P+R)", color = Color(0xFF1976D2), fontWeight = FontWeight.Medium)
            Spacer(Modifier.height(6.dp))
        }
        if (p.hasRealtimeData) {
            Text("${p.placesDisponibles} / ${p.capaciteTotale} places",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = parkingColorFor(p.availabilityColor))
            Text("État : ${p.etat.displayName}", fontSize = 13.sp, color = Color.Gray)
        } else {
            Text("Capacité : ${p.capaciteTotale}", fontSize = 14.sp)
            Text("Données statiques", fontSize = 11.sp, color = Color.Gray)
        }
        if (p.gestionnaire.isNotEmpty()) {
            Spacer(Modifier.height(6.dp))
            Text("Gestionnaire : ${p.gestionnaire}", fontSize = 12.sp, color = Color.Gray)
        }
        p.horaires?.let {
            Spacer(Modifier.height(6.dp))
            Text("Horaires : $it", fontSize = 12.sp)
        }
        if (p.tarif1h != null || p.tarif24h != null) {
            Spacer(Modifier.height(8.dp))
            HorizontalDivider()
            Spacer(Modifier.height(6.dp))
            Text("Tarifs", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            p.tarif1h?.let  { Text("1h    : ${"%.2f".format(it)} €", fontSize = 12.sp) }
            p.tarif2h?.let  { Text("2h    : ${"%.2f".format(it)} €", fontSize = 12.sp) }
            p.tarif24h?.let { Text("24h   : ${"%.2f".format(it)} €", fontSize = 12.sp) }
            p.aboResident?.let { Text("Abo. résident : ${"%.2f".format(it)} €", fontSize = 12.sp) }
        }
        Spacer(Modifier.height(16.dp))
    }
}

private fun parkingColorFor(c: AvailabilityColor): Color = when (c) {
    AvailabilityColor.GRAY   -> Color.Gray
    AvailabilityColor.GREEN  -> Color(0xFF43A047)
    AvailabilityColor.ORANGE -> Color(0xFFFB8C00)
    AvailabilityColor.RED    -> Color(0xFFE53935)
}

private fun parkingTypeColor(type: ParkingType): Color = when (type) {
    ParkingType.CAR           -> Color(0xFF007AFF)
    ParkingType.BIKE          -> Color(0xFF34C759)
    ParkingType.MOTORIZED_2W  -> Color(0xFFFF9500)
}

private fun parkingTypeIcon(type: ParkingType) = when (type) {
    ParkingType.CAR           -> Icons.Filled.DirectionsCar
    ParkingType.BIKE          -> Icons.Filled.DirectionsBike
    ParkingType.MOTORIZED_2W  -> Icons.Filled.TwoWheeler
}

@Composable
private fun ParkingTypeButton(type: ParkingType, isSelected: Boolean, onClick: () -> Unit) {
    val accent = parkingTypeColor(type)
    val bg = if (isSelected) accent else Color.Transparent
    val fg = if (isSelected) Color.White else accent
    Surface(
        shape = RoundedCornerShape(50),
        color = bg,
        modifier = Modifier.clickable { onClick() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(parkingTypeIcon(type), null, tint = fg, modifier = Modifier.size(16.dp))
            Text(type.displayName, color = fg, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun ParkingFilterSheet(
    showParcRelais: Boolean,
    onToggleParcRelais: () -> Unit,
    showRealtimeParkings: Boolean,
    onToggleRealtime: () -> Unit
) {
    Column(modifier = Modifier.padding(20.dp)) {
        Text("Filtres", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(16.dp))
        Surface(shape = RoundedCornerShape(12.dp), color = Color(0xFFF2F2F7), modifier = Modifier.fillMaxWidth()) {
            Column {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp).fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Parkings temps réel", fontSize = 14.sp, fontWeight = FontWeight.Medium)
                        Text("Affiche les parkings publics avec disponibilité", fontSize = 11.sp, color = Color(0xFF8E8E93))
                    }
                    Switch(checked = showRealtimeParkings, onCheckedChange = { onToggleRealtime() })
                }
                HorizontalDivider(modifier = Modifier.padding(start = 14.dp))
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp).fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Parc Relais (P+R)", fontSize = 14.sp, fontWeight = FontWeight.Medium)
                        Text("Afficher les parkings relais TCL", fontSize = 11.sp, color = Color(0xFF8E8E93))
                    }
                    Switch(checked = showParcRelais, onCheckedChange = { onToggleParcRelais() })
                }
            }
        }
        Spacer(Modifier.height(20.dp))
    }
}

private fun parkingAndroidColor(c: AvailabilityColor): Int = when (c) {
    AvailabilityColor.GRAY   -> AndroidColor.parseColor("#9E9E9E")
    AvailabilityColor.GREEN  -> AndroidColor.parseColor("#43A047")
    AvailabilityColor.ORANGE -> AndroidColor.parseColor("#FB8C00")
    AvailabilityColor.RED    -> AndroidColor.parseColor("#E53935")
}

private fun parkingIconId(color: AvailabilityColor, isParcRelais: Boolean) =
    "parking_${color.name}_${if (isParcRelais) "pr" else "std"}"

private fun parkingMarkerBitmap(color: AvailabilityColor, isParcRelais: Boolean): Bitmap {
    val s = 56
    val bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    canvas.drawCircle(s / 2f, s / 2f, s / 2f - 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = parkingAndroidColor(color); style = Paint.Style.FILL
    })
    canvas.drawCircle(s / 2f, s / 2f, s / 2f - 4f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 4f
    })
    canvas.drawText(if (isParcRelais) "P+R" else "P", s / 2f, s / 2f + 9f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = AndroidColor.WHITE; textSize = 26f; textAlign = Paint.Align.CENTER
        typeface = android.graphics.Typeface.DEFAULT_BOLD
    })
    return bmp
}
