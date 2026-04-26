package com.alertetcl.android.ui.parking

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.PointF
import android.location.LocationManager
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.ElectricCar
import androidx.compose.material.icons.filled.Euro
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.TwoWheeler
import androidx.compose.material.icons.filled.VerticalAlignTop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
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
        Column(modifier = Modifier.fillMaxWidth().statusBarsPadding().padding(8.dp)) {
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
    val context = LocalContext.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Title
        Text(
            p.nom,
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )

        // --- Bannière statique P+R ---
        if (p.isParcRelais && !p.hasRealtimeData) {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = Color(0xFFFFF3E0),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(Icons.Filled.AccessTime, null, tint = Color(0xFFF57C00), modifier = Modifier.size(20.dp))
                    Column {
                        Text("Données statiques uniquement", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFFF57C00))
                        Text("La disponibilité en temps réel n'est pas disponible pour ce P+R.", fontSize = 11.sp, color = Color(0xFF757575))
                    }
                }
            }
        }

        // --- Availability header ---
        ParkingAvailabilityHeader(p)

        // --- Navigation button ---
        Button(
            onClick = {
                val uri = Uri.parse("google.navigation:q=${p.latitude},${p.longitude}&mode=d")
                val intent = Intent(Intent.ACTION_VIEW, uri).apply { setPackage("com.google.android.apps.maps") }
                val fallback = Intent(Intent.ACTION_VIEW, Uri.parse("geo:${p.latitude},${p.longitude}?q=${Uri.encode(p.nom)}"))
                try { context.startActivity(intent) } catch (e: Exception) { context.startActivity(fallback) }
            },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF007AFF)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(Icons.Filled.Navigation, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Itinéraire", fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        }

        // --- Main info card ---
        ParkingInfoCard(p)

        // --- Tarifs ---
        val hasTarifs = p.tarif1h != null || p.tarif24h != null || p.gratuit
        if (!p.isParcRelais && hasTarifs) {
            ParkingTarifCard(p)
        }

        // --- Services ---
        val hasServices = (p.nbPmr ?: 0) > 0 || (p.nbVoituresElectriques ?: 0) > 0 ||
            (p.nbVelo ?: 0) > 0 || (p.nb2Rm ?: 0) > 0 || (p.nbAutopartage ?: 0) > 0
        if (!p.isParcRelais && hasServices) {
            ParkingServicesCard(p)
        }

        // --- Additional info ---
        if (!p.isParcRelais) {
            ParkingAdditionalCard(p)
        }

        // --- URL ---
        p.url?.let { urlStr ->
            FilledTonalButton(
                onClick = {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(urlStr)))
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Filled.Language, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("Site web du parking", fontSize = 14.sp)
            }
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun ParkingAvailabilityHeader(p: Parking) {
    val accentColor = parkingColorFor(p.availabilityColor)
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Circular availability indicator
            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(120.dp)) {
                val sweep = if (p.hasRealtimeData && p.capaciteTotale > 0)
                    (1f - p.tauxOccupation.toFloat()).coerceIn(0f, 1f) * 360f else 0f
                Canvas(modifier = Modifier.size(120.dp)) {
                    val stroke = Stroke(width = 12.dp.toPx(), cap = StrokeCap.Round)
                    val inset = 6.dp.toPx()
                    val arcSize = Size(size.width - inset * 2, size.height - inset * 2)
                    val arcOffset = Offset(inset, inset)
                    // Track
                    drawArc(
                        color = accentColor.copy(alpha = 0.2f),
                        startAngle = -90f, sweepAngle = 360f,
                        useCenter = false, topLeft = arcOffset, size = arcSize, style = stroke
                    )
                    // Progress
                    if (sweep > 0f) drawArc(
                        color = accentColor,
                        startAngle = -90f, sweepAngle = sweep,
                        useCenter = false, topLeft = arcOffset, size = arcSize, style = stroke
                    )
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    if (p.hasRealtimeData) {
                        Text(
                            "${p.placesDisponibles}",
                            fontSize = 32.sp, fontWeight = FontWeight.Bold, color = accentColor
                        )
                    } else {
                        Text("—", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                    }
                    Text("/ ${p.capaciteTotale}", fontSize = 12.sp, color = Color.Gray)
                }
            }

            // Status row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                if (p.isParcRelais) {
                    val (ic, col, lbl) = if (p.hasRealtimeData)
                        Triple(Icons.Filled.CheckCircle, Color(0xFF43A047), "Données en direct")
                    else Triple(Icons.Filled.AccessTime, Color(0xFFF57C00), "Données statiques")
                    Icon(ic, null, tint = col, modifier = Modifier.size(18.dp))
                    Text(lbl, fontWeight = FontWeight.SemiBold, color = col)
                } else {
                    val (ic, col, lbl) = if (p.etat.raw == "ouvert")
                        Triple(Icons.Filled.CheckCircle, Color(0xFF43A047), "Ouvert")
                    else Triple(Icons.Filled.Info, Color(0xFFE53935), p.etat.displayName)
                    Icon(ic, null, tint = col, modifier = Modifier.size(18.dp))
                    Text(lbl, fontWeight = FontWeight.SemiBold, color = col)
                }
            }
        }
    }
}

@Composable
private fun ParkingInfoCard(p: Parking) {
    ParkingCard(title = "Informations", icon = Icons.Filled.Info, iconColor = Color(0xFF007AFF)) {
        if (!p.isParcRelais && p.gestionnaire.isNotEmpty()) {
            ParkingInfoRow(icon = Icons.Filled.Build, label = "Gestionnaire", value = p.gestionnaire)
        }
        p.hauteurMax?.let { h ->
            ParkingInfoRow(icon = Icons.Filled.VerticalAlignTop, label = "Hauteur max", value = "$h cm")
        }
        ParkingInfoRow(icon = Icons.Filled.DirectionsCar, label = "Capacité totale", value = "${p.capaciteTotale} places")
        val pmr = p.nbPmr ?: 0
        if (pmr > 0) ParkingInfoRow(icon = Icons.Filled.Person, label = "Places PMR", value = "$pmr places")
        if (p.isParcRelais) {
            p.horaires?.let { h -> ParkingInfoRow(icon = Icons.Filled.AccessTime, label = "Horaires", value = h) }
            p.surveille?.let { s ->
                ParkingInfoRow(
                    icon = Icons.Filled.Security, label = "Surveillance",
                    value = if (s) "Parc surveillé" else "Non surveillé"
                )
            }
        }
    }
}

@Composable
private fun ParkingTarifCard(p: Parking) {
    ParkingCard(title = "Tarifs", icon = Icons.Filled.Euro, iconColor = Color(0xFF43A047)) {
        if (p.gratuit) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.CheckCircle, null, tint = Color(0xFF43A047), modifier = Modifier.size(18.dp))
                Text("Parking gratuit", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            }
        } else {
            val tarifs = listOfNotNull(
                p.tarif1h?.let { "1h" to it },
                p.tarif2h?.let { "2h" to it },
                p.tarif3h?.let { "3h" to it },
                p.tarif4h?.let { "4h" to it },
                p.tarif24h?.let { "24h" to it }
            )
            if (tarifs.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    tarifs.forEach { (dur, price) ->
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier.weight(1f)
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.padding(vertical = 10.dp)
                            ) {
                                Text(dur, fontSize = 11.sp, color = Color.Gray)
                                Text("${"%.2f".format(price)}€", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
            val hasAbo = p.aboResident != null || p.aboNonResident != null
            if (hasAbo) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                Text("Abonnements", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(4.dp))
                p.aboResident?.let {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text("Résident", fontSize = 13.sp, color = Color.Gray, modifier = Modifier.weight(1f))
                        Text("${"%.0f".format(it)}€/mois", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
                p.aboNonResident?.let {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text("Non-résident", fontSize = 13.sp, color = Color.Gray, modifier = Modifier.weight(1f))
                        Text("${"%.0f".format(it)}€/mois", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

@Composable
private fun ParkingServicesCard(p: Parking) {
    data class ServiceItem(val icon: ImageVector, val label: String, val count: Int, val color: Color)
    val services = listOfNotNull(
        p.nbPmr?.takeIf { it > 0 }?.let { ServiceItem(Icons.Filled.Person, "PMR", it, Color(0xFF007AFF)) },
        p.nbVoituresElectriques?.takeIf { it > 0 }?.let { ServiceItem(Icons.Filled.ElectricCar, "Électrique", it, Color(0xFF43A047)) },
        p.nbVelo?.takeIf { it > 0 }?.let { ServiceItem(Icons.Filled.DirectionsBike, "Vélos", it, Color(0xFFFF9500)) },
        p.nb2Rm?.takeIf { it > 0 }?.let { ServiceItem(Icons.Filled.TwoWheeler, "2 roues", it, Color(0xFFE53935)) },
        p.nbAutopartage?.takeIf { it > 0 }?.let { ServiceItem(Icons.Filled.DirectionsCar, "Autopartage", it, Color(0xFF9C27B0)) }
    )
    ParkingCard(title = "Services", icon = Icons.Filled.Build, iconColor = Color(0xFF9C27B0)) {
        val rows = services.chunked(2)
        rows.forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                rowItems.forEach { svc ->
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = MaterialTheme.colorScheme.surface,
                        modifier = Modifier.weight(1f)
                    ) {
                        Row(
                            modifier = Modifier.padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(svc.icon, null, tint = svc.color, modifier = Modifier.size(20.dp))
                            Column {
                                Text("${svc.count}", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                Text(svc.label, fontSize = 11.sp, color = Color.Gray)
                            }
                        }
                    }
                }
                if (rowItems.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun ParkingAdditionalCard(p: Parking) {
    ParkingCard(title = "Informations complémentaires", icon = Icons.Filled.Info, iconColor = Color(0xFFFF9500)) {
        ParkingInfoRow(icon = Icons.Filled.Person, label = "Type d'usagers", value = "Tous publics")
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            val (ic, col, lbl) = if (p.gratuit)
                Triple(Icons.Filled.CheckCircle, Color(0xFF43A047), "Gratuit")
            else Triple(Icons.Filled.Euro, Color(0xFFFF9500), "Payant")
            Icon(ic, null, tint = col, modifier = Modifier.size(18.dp))
            Column {
                Text("Statut", fontSize = 11.sp, color = Color.Gray)
                Text(lbl, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = col)
            }
        }
    }
}

@Composable
private fun ParkingCard(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    content: @Composable () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(icon, null, tint = iconColor, modifier = Modifier.size(18.dp))
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            }
            content()
        }
    }
}

@Composable
private fun ParkingInfoRow(icon: ImageVector, label: String, value: String) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Icon(icon, null, tint = Color.Gray, modifier = Modifier.size(16.dp).padding(top = 2.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(label, fontSize = 11.sp, color = Color.Gray)
            Text(value, fontSize = 14.sp)
        }
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
