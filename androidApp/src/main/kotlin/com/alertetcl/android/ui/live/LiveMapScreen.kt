package com.alertetcl.android.ui.live

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF
import android.graphics.Typeface
import android.Manifest
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Accessible
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material3.IconButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
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
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.BusLine
import com.alertetcl.shared.models.ClusteringEngine
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.models.TransitLine
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import com.alertetcl.shared.services.BusLineService
import com.alertetcl.shared.services.TransitLineService
import com.alertetcl.shared.services.TransitStopService
import com.alertetcl.shared.viewmodels.LiveVehiclesViewModel
import com.google.gson.JsonObject
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import kotlin.math.max
import kotlin.math.pow

// Tuiles OpenFreeMap — 100% gratuit, sans clé API
private const val STYLE_URL_LIBERTY = "https://tiles.openfreemap.org/styles/liberty"

// Style satellite via raster ESRI World Imagery (free, no key)
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

private const val TRANSIT_SRC     = "transit-src"
private const val BUS_SRC         = "bus-src"
private const val VEHICLES_SRC    = "vehicles-src"
private const val STOPS_SRC       = "stops-src"
private const val TRANSIT_LAYER   = "transit-layer"
private const val BUS_LAYER       = "bus-layer"
private const val VEHICLES_LAYER  = "vehicles-layer"
private const val VEHICLES_ARROW_LAYER = "vehicles-arrow-layer"
private const val STOPS_LAYER       = "stops-layer"        // CircleLayer mode compact
private const val STOPS_BADGE_LAYER = "stops-badge-layer"  // SymbolLayer mode badges (zoom serré)
private const val STOPS_COMPACT_KEY = "stop_compact"

@Composable
private fun rememberMapView(): MapView {
    val context = LocalContext.current
    val mapView = remember { MapView(context) }
    DisposableEffect(Unit) {
        mapView.onCreate(null)
        mapView.onStart()
        mapView.onResume()
        onDispose {
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }
    return mapView
}

/** Normalise un hex TCL vers #RRGGBB lisible par MapLibre */
private fun toMapColor(hex: String): String {
    val c = hex.trim().removePrefix("#")
    return when (c.length) {
        6 -> "#$c"
        8 -> "#${c.substring(2)}" // drop alpha
        else -> "#888888"
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveMapScreen() {
    val vm = remember { LiveVehiclesViewModel() }
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // Lifecycle: stop polling on background, restart on resume (parité iOS scenePhase)
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> vm.startPolling()
                Lifecycle.Event.ON_STOP  -> vm.stopPolling()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            vm.dispose()
        }
    }
    val vehicles     by vm.vehicles.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val isLoading    by vm.isLoading.collectAsState()
    val vehiclesError by vm.errorMessage.collectAsState()
    val isLive       by vm.isLive.collectAsState()
    val lastUpdateMs by vm.lastUpdateEpochMs.collectAsState()

    // Alertes pour le bandeau trafic en haut
    val alertsVm = remember { com.alertetcl.shared.viewmodels.AlertsViewModel() }
    DisposableEffect(Unit) {
        alertsVm.startPolling()
        onDispose { alertsVm.dispose() }
    }
    val alerts by alertsVm.alerts.collectAsState()
    val alertsError by alertsVm.errorMessage.collectAsState()

    val store = remember { com.alertetcl.android.data.FavoritesStore(context) }
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())

    var showLineTraces by remember { mutableStateOf(true) }
    var isSatellite    by remember { mutableStateOf(false) }

    val transitLines = produceState<List<TransitLine>>(initialValue = emptyList()) {
        value = runCatching { TransitLineService.shared.fetchTransitLines() }.getOrDefault(emptyList())
    }
    val busLines = produceState<List<BusLine>>(initialValue = emptyList()) {
        value = runCatching { BusLineService.shared.fetchBusLines() }.getOrDefault(emptyList())
    }
    // Chargé une seule fois au démarrage (comme iOS), affichage contrôlé par zoom/toggle
    val stops = produceState<List<TransitStop>>(initialValue = emptyList()) {
        value = runCatching { TransitStopService.shared.fetchStops() }.getOrDefault(emptyList())
    }

    // Animation tick every 100 ms
    var tick by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        while (true) { kotlinx.coroutines.delay(100); tick++ }
    }
    // Tick 1s pour le countdown LIVE
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) { kotlinx.coroutines.delay(1000); nowMs = System.currentTimeMillis() }
    }

    val filteredVehicles by remember {
        derivedStateOf { tick; vehicles.filter { it.vehicleType in selectedTypes } }
    }

    // MapLibre state
    var mapLibreMap  by remember { mutableStateOf<MapLibreMap?>(null) }
    var mapStyle     by remember { mutableStateOf<Style?>(null) }
    var currentZoom  by remember { mutableDoubleStateOf(12.5) }
    var visibleBounds by remember { mutableStateOf<LatLngBounds?>(null) }

    // Stable mutable refs readable from non-composable callbacks
    val vehiclesRef = remember { mutableStateOf<List<Vehicle>>(emptyList()) }
    val stopsRef    = remember { mutableStateOf<List<TransitStop>>(emptyList()) }
    vehiclesRef.value = filteredVehicles
    stopsRef.value    = stops.value

    // Parité iOS exacte :
    //   stopsZoomThreshold   = 0.018  → afficher les arrêts
    //   stopBadgeZoomThreshold = 0.005 → afficher les badges de ligne
    // (iOS utilise latitudeDelta en degrés depuis MKCoordinateSpan)
    val latitudeDelta by remember {
        derivedStateOf {
            visibleBounds?.let { it.northEast.latitude - it.southWest.latitude } ?: Double.MAX_VALUE
        }
    }
    val stopsVisible by remember { derivedStateOf { latitudeDelta <= 0.018 } }
    val showBadges   by remember { derivedStateOf { latitudeDelta <= 0.005 } }

    val visibleClusters by remember {
        derivedStateOf {
            if (!stopsVisible) emptyList()
            else {
                val bounds = visibleBounds
                val filtered = if (bounds != null) {
                    val ne = bounds.northEast; val sw = bounds.southWest
                    val latBuf = (ne.latitude  - sw.latitude)  * 0.3
                    val lonBuf = (ne.longitude - sw.longitude) * 0.3
                    stopsRef.value.filter { s ->
                        s.latitude  in (sw.latitude  - latBuf)..(ne.latitude  + latBuf) &&
                        s.longitude in (sw.longitude - lonBuf)..(ne.longitude + lonBuf)
                    }
                } else stopsRef.value
                ClusteringEngine.cluster(filtered, max(0.001, 80.0 / 2.0.pow(currentZoom)))
            }
        }
    }

    // Selection state
    val selectedVehicle = remember { mutableStateOf<Vehicle?>(null) }
    val selectedStop    = remember { mutableStateOf<TransitStop?>(null) }

    // Bottom sheet flags
    var showAlertsSheet by remember { mutableStateOf(false) }
    var showFilterSheet by remember { mutableStateOf(false) }
    var showErrorsSheet by remember { mutableStateOf(false) }
    var showRefreshInfo by remember { mutableStateOf(false) }
    var showStops       by remember { mutableStateOf(true) }

    // Permission location pour le FAB localisation
    val locationPermLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) recenterOnUser(context, mapLibreMap)
    }

    val mapView = rememberMapView()

    // Filtres actifs (parité iOS hasActiveFilters — les arrêts sont automatiques, pas un filtre)
    val hasActiveFilters = selectedTypes.size != VehicleType.entries.size || !showLineTraces

    // ── UI ────────────────────────────────────────────────────────────────
    Box(modifier = Modifier.fillMaxSize()) {

        // Map
        AndroidView(
            factory = { _ ->
                mapView.also { mv ->
                    mv.getMapAsync { map ->
                        mapLibreMap = map
                        map.uiSettings.isLogoEnabled         = false
                        map.uiSettings.isAttributionEnabled  = false
                        map.uiSettings.isCompassEnabled      = true
                        map.cameraPosition = CameraPosition.Builder()
                            .target(LatLng(45.764043, 4.835659))
                            .zoom(12.5)
                            .build()
                        map.addOnCameraIdleListener {
                            currentZoom = map.cameraPosition.zoom
                            visibleBounds = map.projection.visibleRegion.latLngBounds
                        }
                        map.addOnMapClickListener { latLng ->
                            val screen = map.projection.toScreenLocation(latLng)
                            val pt = PointF(screen.x, screen.y)
                            val vf = map.queryRenderedFeatures(pt, VEHICLES_LAYER)
                            if (vf.isNotEmpty()) {
                                selectedVehicle.value = vehiclesRef.value.find { it.id == vf[0].getStringProperty("id") }
                                return@addOnMapClickListener true
                            }
                            val sf = map.queryRenderedFeatures(pt, STOPS_LAYER)
                            if (sf.isNotEmpty()) {
                                val sid = sf[0].getNumberProperty("id")?.toInt()
                                selectedStop.value = stopsRef.value.find { it.id == sid }
                                return@addOnMapClickListener true
                            }
                            false
                        }
                        map.setStyle(Style.Builder().fromUri(STYLE_URL_LIBERTY)) { style ->
                            visibleBounds = map.projection.visibleRegion.latLngBounds
                            mapStyle = style
                        }
                    }
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Switch base style when satellite toggled (re-applies layers via mapStyle observer)
        LaunchedEffect(isSatellite) {
            val map = mapLibreMap ?: return@LaunchedEffect
            val builder = if (isSatellite) Style.Builder().fromJson(STYLE_JSON_SATELLITE)
                          else              Style.Builder().fromUri(STYLE_URL_LIBERTY)
            mapStyle = null
            map.setStyle(builder) { style -> mapStyle = style }
        }

        // ── Top: Traffic Banner (parité iOS) ─────────────────────────────
        TrafficBanner(
            subscribedLines = favorites,
            alerts = alerts,
            lastUpdateMs = lastUpdateMs,
            hasError = vehiclesError != null || alertsError != null,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .fillMaxWidth(),
            onTap = { showAlertsSheet = true }
        )

        // ── Bottom-left: Live Indicator ──────────────────────────────────
        Column(
            modifier = Modifier.align(Alignment.BottomStart).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (vehiclesError != null || alertsError != null) {
                Surface(
                    shape = RoundedCornerShape(50),
                    color = Color(0xFFFFF4E5),
                    shadowElevation = 4.dp,
                    modifier = Modifier.clickable { showErrorsSheet = true }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Filled.Warning, null, tint = Color(0xFFFF9500), modifier = Modifier.size(14.dp))
                        val n = (if (vehiclesError != null) 1 else 0) + (if (alertsError != null) 1 else 0)
                        Text("$n source${if (n > 1) "s" else ""} en erreur", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    }
                }
            }
            LiveIndicator(
                isLive = isLive,
                isLoading = isLoading,
                lastUpdateMs = lastUpdateMs,
                nowMs = nowMs,
                hasError = vehiclesError != null,
                onTap = { showRefreshInfo = true }
            )
        }

        // ── Bottom-right: 3 FABs (satellite, filters, location) ─────────
        Column(
            modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            CircleFab(
                icon = Icons.Filled.Public, contentDesc = "Vue satellite",
                tint = if (isSatellite) Color(0xFFFF9500) else Color(0xFF1C1C1E),
                onClick = { isSatellite = !isSatellite }
            )
            CircleFab(
                icon = Icons.Filled.FilterList, contentDesc = "Filtres",
                tint = if (hasActiveFilters) Color(0xFF007AFF) else Color(0xFF1C1C1E),
                onClick = { showFilterSheet = true }
            )
            CircleFab(
                icon = Icons.Filled.MyLocation, contentDesc = "Ma position",
                tint = Color(0xFF007AFF),
                onClick = {
                    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
                        context, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) recenterOnUser(context, mapLibreMap)
                    else locationPermLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                }
            )
        }
    }

    // ── Map update effects ──────────────────────────────────────────────

    // Line traces (transit + bus)
    LaunchedEffect(mapStyle, showLineTraces, transitLines.value, busLines.value) {
        val style = mapStyle ?: return@LaunchedEffect

        val transitFeatures = if (showLineTraces) transitLines.value.mapNotNull { line ->
            val pts = line.coordinates.mapNotNull { c -> if (c.size < 2) null else Point.fromLngLat(c[0], c[1]) }
            if (pts.size < 2) null else {
                val props = JsonObject().apply { addProperty("color", toMapColor(line.strokeColorHex)) }
                Feature.fromGeometry(LineString.fromLngLats(pts), props)
            }
        } else emptyList()

        val busFeatures = if (showLineTraces) busLines.value.mapNotNull { line ->
            val pts = line.coordinates.mapNotNull { c -> if (c.size < 2) null else Point.fromLngLat(c[0], c[1]) }
            if (pts.size < 2) null else {
                val props = JsonObject().apply { addProperty("color", toMapColor(LineColors.routeStrokeHex(line.name))) }
                Feature.fromGeometry(LineString.fromLngLats(pts), props)
            }
        } else emptyList()

        if (style.getSource(TRANSIT_SRC) == null) {
            style.addSource(GeoJsonSource(TRANSIT_SRC, FeatureCollection.fromFeatures(transitFeatures)))
            style.addLayer(LineLayer(TRANSIT_LAYER, TRANSIT_SRC).withProperties(
                PropertyFactory.lineColor(Expression.get("color")),
                PropertyFactory.lineWidth(8f),
                PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(TRANSIT_SRC)?.setGeoJson(FeatureCollection.fromFeatures(transitFeatures))
        }

        if (style.getSource(BUS_SRC) == null) {
            style.addSource(GeoJsonSource(BUS_SRC, FeatureCollection.fromFeatures(busFeatures)))
            style.addLayer(LineLayer(BUS_LAYER, BUS_SRC).withProperties(
                PropertyFactory.lineColor(Expression.get("color")),
                PropertyFactory.lineWidth(4f),
                PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(BUS_SRC)?.setGeoJson(FeatureCollection.fromFeatures(busFeatures))
        }
    }

    // Vehicle markers
    LaunchedEffect(mapStyle, filteredVehicles) {
        val style = mapStyle ?: return@LaunchedEffect

        // Register circle body + arrow icons (once per unique line)
        if (style.getImage("no_arrow") == null)
            style.addImage("no_arrow", Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))

        filteredVehicles.forEach { v ->
            val iconId  = "v_${v.lineName.replace(Regex("[^A-Za-z0-9]"), "_")}"
            val arrowId = "va_${v.lineName.replace(Regex("[^A-Za-z0-9]"), "_")}"
            if (style.getImage(iconId)  == null) style.addImage(iconId,  vehicleMarkerBitmap(v.lineName))
            if (style.getImage(arrowId) == null) style.addImage(arrowId, bearingArrowBitmap(v.lineName))
        }

        val features = filteredVehicles.map { v ->
            val animated = vm.animatedVehicleFor(v.id)
            val nowSec   = System.currentTimeMillis() / 1000.0
            val coord    = animated?.currentInterpolatedCoordinate(nowSec) ?: v.coordinate
            val bearing  = animated?.currentInterpolatedBearing(nowSec) ?: v.bearing
            val iconId   = "v_${v.lineName.replace(Regex("[^A-Za-z0-9]"), "_")}"
            val arrowId  = "va_${v.lineName.replace(Regex("[^A-Za-z0-9]"), "_")}"
            val props    = JsonObject().apply {
                addProperty("id",          v.id)
                addProperty("line",        v.lineName)
                addProperty("destination", v.destination)
                addProperty("icon",        iconId)
                addProperty("arrow_icon",  if (bearing != 0.0) arrowId else "no_arrow")
                addProperty("bearing",     bearing.toFloat())
            }
            Feature.fromGeometry(Point.fromLngLat(coord.longitude, coord.latitude), props)
        }

        if (style.getSource(VEHICLES_SRC) == null) {
            style.addSource(GeoJsonSource(VEHICLES_SRC, FeatureCollection.fromFeatures(features)))
            // Layer 1 : corps cercle (sans rotation — texte reste lisible)
            style.addLayer(SymbolLayer(VEHICLES_LAYER, VEHICLES_SRC).withProperties(
                PropertyFactory.iconImage(Expression.get("icon")),
                PropertyFactory.iconAllowOverlap(true),
                PropertyFactory.iconIgnorePlacement(true),
                PropertyFactory.iconSize(1f)
            ))
            // Layer 2 : flèche orbitale (tourne selon le bearing, comme iOS)
            style.addLayer(SymbolLayer(VEHICLES_ARROW_LAYER, VEHICLES_SRC).withProperties(
                PropertyFactory.iconImage(Expression.get("arrow_icon")),
                PropertyFactory.iconRotate(Expression.toNumber(Expression.get("bearing"))),
                PropertyFactory.iconRotationAlignment(Property.ICON_ROTATION_ALIGNMENT_MAP),
                PropertyFactory.iconOffset(arrayOf(0f, -28f)),
                PropertyFactory.iconAllowOverlap(true),
                PropertyFactory.iconIgnorePlacement(true),
                PropertyFactory.iconSize(1f)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(VEHICLES_SRC)?.setGeoJson(FeatureCollection.fromFeatures(features))
        }
    }

    // Stops — parit\u00e9 iOS exacte
    // - Compact (cercle blanc/bleu)  : stopsVisible && !showBadges
    // - Badges  (dot + capsules)     : stopsVisible && showBadges
    LaunchedEffect(mapStyle, stopsVisible, showBadges, visibleClusters) {
        val style = mapStyle ?: return@LaunchedEffect

        // Enregistrer l'ic\u00f4ne compacte une seule fois par style
        if (style.getImage(STOPS_COMPACT_KEY) == null) {
            style.addImage(STOPS_COMPACT_KEY, stopCompactBitmap())
        }

        // Construire les features (arr\u00eats individuels seulement — pas de clusters \u00e0 ce zoom)
        val features = if (!stopsVisible) emptyList()
        else visibleClusters.filter { it.count == 1 }.map { cl ->
            val s = cl.items.first()
            val props = JsonObject().apply { addProperty("id", s.id) }
            if (showBadges) {
                val visibleLines = s.lines.filter { !it.startsWith("JD", ignoreCase = true) }
                if (visibleLines.isNotEmpty()) {
                    val iconKey = "stop_" + visibleLines.take(4).joinToString("_")
                    if (style.getImage(iconKey) == null) {
                        style.addImage(iconKey, stopBadgeBitmap(visibleLines))
                    }
                    props.addProperty("icon", iconKey)
                } else {
                    props.addProperty("icon", STOPS_COMPACT_KEY)
                }
            }
            Feature.fromGeometry(Point.fromLngLat(s.coordinate.longitude, s.coordinate.latitude), props)
        }

        if (style.getSource(STOPS_SRC) == null) {
            style.addSource(GeoJsonSource(STOPS_SRC, FeatureCollection.fromFeatures(features)))

            // Layer 1 : disque compact (CircleLayer)
            style.addLayer(CircleLayer(STOPS_LAYER, STOPS_SRC).withProperties(
                PropertyFactory.circleColor("#FFFFFF"),
                PropertyFactory.circleRadius(5f),
                PropertyFactory.circleStrokeColor("#1976D2"),
                PropertyFactory.circleStrokeWidth(2f)
            ))

            // Layer 2 : badges de ligne (SymbolLayer, visible seulement en mode badge)
            // ICON_ANCHOR_CENTER : le bitmap est conçu pour que le centre du dot
            // coïncide avec le centre vertical du bitmap (via top padding = badgeH + gap)
            style.addLayer(SymbolLayer(STOPS_BADGE_LAYER, STOPS_SRC).withProperties(
                PropertyFactory.iconImage(Expression.get("icon")),
                PropertyFactory.iconAllowOverlap(true),
                PropertyFactory.iconIgnorePlacement(true),
                PropertyFactory.iconAnchor(Property.ICON_ANCHOR_CENTER)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(STOPS_SRC)?.setGeoJson(FeatureCollection.fromFeatures(features))
        }

        val compactVis = if (stopsVisible && !showBadges) Property.VISIBLE else Property.NONE
        val badgeVis   = if (stopsVisible && showBadges)  Property.VISIBLE else Property.NONE
        style.getLayer(STOPS_LAYER)?.setProperties(PropertyFactory.visibility(compactVis))
        style.getLayer(STOPS_BADGE_LAYER)?.setProperties(PropertyFactory.visibility(badgeVis))
    }

    // ── Bottom sheets ───────────────────────────────────────────────────

    selectedVehicle.value?.let { v ->
        ModalBottomSheet(onDismissRequest = { selectedVehicle.value = null }, sheetState = rememberModalBottomSheetState()) {
            VehicleDetailSheet(v)
        }
    }
    selectedStop.value?.let { stop ->
        ModalBottomSheet(onDismissRequest = { selectedStop.value = null }, sheetState = rememberModalBottomSheetState()) {
            StopDetailSheet(stop)
        }
    }
    if (showAlertsSheet) {
        ModalBottomSheet(onDismissRequest = { showAlertsSheet = false }, sheetState = rememberModalBottomSheetState()) {
            Box(Modifier.fillMaxSize()) { com.alertetcl.android.ui.alerts.AlertsScreen() }
        }
    }
    if (showFilterSheet) {
        ModalBottomSheet(onDismissRequest = { showFilterSheet = false }, sheetState = rememberModalBottomSheetState()) {
            FilterSheet(
                selectedTypes = selectedTypes,
                onToggleType = { vm.toggleType(it) },
                showLineTraces = showLineTraces,
                onToggleTraces = { showLineTraces = !showLineTraces }
            )
        }
    }
    if (showRefreshInfo) {
        ModalBottomSheet(onDismissRequest = { showRefreshInfo = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            RefreshInfoSheet(lastUpdateMs = lastUpdateMs)
        }
    }
    if (showErrorsSheet) {
        ModalBottomSheet(onDismissRequest = { showErrorsSheet = false }, sheetState = rememberModalBottomSheetState()) {
            DataSourceErrorsSheet(
                vehiclesError = vehiclesError, alertsError = alertsError,
                onRetryVehicles = { vm.refresh() }, onRetryAlerts = { alertsVm.refresh() },
                onDismiss = { showErrorsSheet = false }
            )
        }
    }
}

// ── Detail sheets ────────────────────────────────────────────────────────

@Composable
private fun VehicleDetailSheet(v: Vehicle) {
    val accentColor = Color(android.graphics.Color.parseColor(v.vehicleType.clusterColorHex))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 24.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // ── Header card ──
        Surface(
            shape = RoundedCornerShape(20.dp),
            color = Color.White,
            shadowElevation = 3.dp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 16.dp)
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Icône colorée 64×64
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = accentColor,
                    shadowElevation = 4.dp,
                    modifier = Modifier.size(64.dp)
                ) {
                    Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            Icon(
                                imageVector = vehicleTypeIcon(v.vehicleType),
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(20.dp)
                            )
                            Text(
                                text = v.lineName,
                                color = Color.White,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                // Textes droite
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Text(
                        text = v.vehicleType.displayName.uppercase(),
                        color = accentColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        letterSpacing = 0.5.sp
                    )
                    val cleanDest = v.destination.trim()
                    if (cleanDest.isNotEmpty() && !cleanDest.contains(":") && cleanDest.length < 60) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Icon(Icons.Filled.ArrowForward, null, tint = Color(0xFF8E8E93), modifier = Modifier.size(12.dp))
                            Text(cleanDest, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                        }
                    }
                    // Pastille retard
                    val delayColor = when {
                        v.isDelayed -> Color(0xFFFF9500)
                        v.isEarly   -> Color(0xFF007AFF)
                        else        -> Color(0xFF34C759)
                    }
                    Surface(shape = RoundedCornerShape(50), color = delayColor.copy(alpha = 0.12f)) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(Icons.Filled.AccessTime, null, tint = delayColor, modifier = Modifier.size(11.dp))
                            Text(v.delayFormatted, color = delayColor, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }

        // ── Timeline prochain arrêt ──
        v.nextStop?.let { ns ->
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = Color.White,
                shadowElevation = 3.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
                    Text(
                        text = "PROCHAIN ARRÊT",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF8E8E93),
                        letterSpacing = 0.5.sp
                    )
                    Spacer(Modifier.height(12.dp))
                    Row {
                        // Colonne dot
                        Box(
                            modifier = Modifier.width(28.dp).padding(top = 14.dp),
                            contentAlignment = Alignment.TopCenter
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(24.dp)
                                    .clip(CircleShape)
                                    .background(accentColor.copy(alpha = 0.2f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(12.dp)
                                        .clip(CircleShape)
                                        .background(accentColor)
                                )
                            }
                        }
                        // Contenu
                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .padding(start = 12.dp, top = 16.dp, bottom = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(
                                modifier = Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(2.dp)
                            ) {
                                Text(
                                    text = ns.stopName ?: ns.stopRef,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1
                                )
                                Text("Prochain arrêt", fontSize = 10.sp, color = accentColor, fontWeight = FontWeight.Medium)
                            }
                            val arrivalEpoch = ns.aimedArrivalTimeEpoch ?: ns.aimedDepartureTimeEpoch
                            if (arrivalEpoch != null) {
                                val time = java.time.Instant.ofEpochMilli(arrivalEpoch)
                                    .atZone(java.time.ZoneId.systemDefault())
                                val timeStr = java.time.format.DateTimeFormatter.ofPattern("HH:mm").format(time)
                                val minsUntil = (arrivalEpoch - System.currentTimeMillis()) / 60000L
                                Column(
                                    horizontalAlignment = Alignment.End,
                                    verticalArrangement = Arrangement.spacedBy(1.dp)
                                ) {
                                    Text(
                                        text = timeStr,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
                                    )
                                    if (minsUntil > 0) {
                                        Text(
                                            text = "dans $minsUntil min",
                                            fontSize = 10.sp,
                                            color = accentColor,
                                            fontWeight = FontWeight.Medium
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Footer mis à jour ──
        v.recordedAtEpoch?.let { epoch ->
            val timeStr = java.time.format.DateTimeFormatter.ofPattern("HH:mm").format(
                java.time.Instant.ofEpochMilli(epoch).atZone(java.time.ZoneId.systemDefault())
            )
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.Public, null, tint = Color(0xFFAEAEB2), modifier = Modifier.size(11.dp))
                Spacer(Modifier.width(5.dp))
                Text("Mis à jour à $timeStr", fontSize = 10.sp, color = Color(0xFFAEAEB2))
            }
        }
    }
}

private fun vehicleTypeIcon(type: VehicleType): androidx.compose.ui.graphics.vector.ImageVector = when (type) {
    VehicleType.BUS, VehicleType.TROLLEY -> Icons.Filled.DirectionsBus
    else -> Icons.Filled.Tram
}

// ── Bottom-sheet helpers ─────────────────────────────────────────────────

@Composable
private fun CircleFab(icon: androidx.compose.ui.graphics.vector.ImageVector, contentDesc: String,
                     tint: Color, onClick: () -> Unit) {
    Surface(shape = CircleShape, color = Color.White.copy(alpha = 0.95f),
        tonalElevation = 6.dp, shadowElevation = 6.dp,
        modifier = Modifier.size(50.dp)) {
        IconButton(onClick = onClick, modifier = Modifier.fillMaxSize()) {
            Icon(icon, contentDesc, tint = tint, modifier = Modifier.size(22.dp))
        }
    }
}

private data class LineDirectionKey(val line: String, val direction: String)

@Composable
private fun StopDetailSheet(stop: TransitStop) {
    val passages = produceState<List<Passage>?>(initialValue = null, stop.id) {
        value = runCatching { TransitStopService.shared.fetchPassagesForStop(stop.id) }.getOrNull() ?: emptyList()
    }
    val groupedPassages = remember(passages.value) {
        val list = passages.value ?: return@remember emptyList<Pair<LineDirectionKey, List<Passage>>>()
        list.groupBy { LineDirectionKey(it.ligne, it.direction) }
            .toList()
            .sortedWith(
                compareBy<Pair<LineDirectionKey, List<Passage>>> {
                    TransportMode.detectFromLine(it.first.line).sortOrder
                }.thenBy { it.first.line }.thenBy { it.first.direction }
            )
    }

    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
        .heightIn(max = 560.dp)
        .verticalScroll(rememberScrollState())) {

        // Header (centered) — iOS parity
        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(
                    modifier = Modifier.size(60.dp).clip(CircleShape)
                        .background(Color(0xFF007AFF).copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Filled.Tram, null, tint = Color(0xFF007AFF), modifier = Modifier.size(28.dp))
                }
                Text(stop.nom, fontWeight = FontWeight.Bold, fontSize = 19.sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                if (stop.commune.isNotEmpty())
                    Text(stop.commune, fontSize = 13.sp, color = Color(0xFF8E8E93))

                if (stop.lines.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        stop.lines.take(6).forEach { line ->
                            com.alertetcl.android.ui.alerts.LineBadge(line, size = 28.dp, fontSize = 12.sp)
                        }
                        if (stop.lines.size > 6) Text("+${stop.lines.size - 6}", fontSize = 11.sp,
                            color = Color(0xFF8E8E93), modifier = Modifier.padding(start = 4.dp))
                    }
                }
                if (stop.pmr) {
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Filled.Accessible, null, tint = Color(0xFF007AFF),
                            modifier = Modifier.size(14.dp))
                        Text("Accessible PMR", fontSize = 11.sp, color = Color(0xFF007AFF))
                    }
                }
            }
        }
        Spacer(Modifier.height(20.dp))

        // Passages section
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                Icons.Filled.AccessTime, null,
                tint = Color(0xFF007AFF), modifier = Modifier.size(15.dp)
            )
            Text("Prochains passages", fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                color = Color(0xFF007AFF))
        }
        Spacer(Modifier.height(12.dp))
        when {
            passages.value == null -> {
                Box(modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                    contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        androidx.compose.material3.CircularProgressIndicator(
                            modifier = Modifier.size(28.dp), strokeWidth = 2.dp)
                        Text("Chargement des passages…", fontSize = 12.sp, color = Color(0xFF8E8E93))
                    }
                }
            }
            groupedPassages.isEmpty() -> {
                Box(modifier = Modifier.fillMaxWidth().padding(vertical = 28.dp),
                    contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(
                            Icons.Filled.AccessTime, null,
                            tint = Color(0xFF8E8E93), modifier = Modifier.size(36.dp)
                        )
                        Text("Aucun passage prévu", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Color(0xFF8E8E93))
                        Text(
                            "Les horaires seront affichés quand des véhicules seront en approche",
                            fontSize = 11.sp, color = Color(0xFF8E8E93),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
            }
            else -> {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    groupedPassages.forEach { (key, list) ->
                        LinePassagesCard(line = key.line, direction = key.direction, passages = list)
                    }
                }
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun LinePassagesCard(line: String, direction: String, passages: List<Passage>) {
    Surface(shape = RoundedCornerShape(14.dp), color = Color.White,
        tonalElevation = 1.dp, shadowElevation = 1.dp,
        modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                com.alertetcl.android.ui.alerts.LineBadge(line, size = 32.dp, fontSize = 13.sp)
                Column(modifier = Modifier.weight(1f)) {
                    Text("Direction", fontSize = 10.sp, color = Color(0xFF8E8E93))
                    Text(direction, fontSize = 13.sp, fontWeight = FontWeight.Medium, maxLines = 2)
                }
            }
            Row(modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                passages.take(4).forEach { p -> PassageChip(p) }
            }
        }
    }
}

@Composable
private fun PassageChip(p: Passage) {
    val bg = if (p.isRealTime) Color(0xFF34C759).copy(alpha = 0.14f) else Color(0xFFF2F2F7)
    val accent = if (p.isRealTime) Color(0xFF34C759) else Color(0xFF8E8E93)
    Surface(shape = RoundedCornerShape(10.dp), color = bg) {
        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            Text(p.delaipassage.ifBlank { "--" }, fontSize = 13.sp,
                fontWeight = FontWeight.Bold, color = accent)
            Text(p.formattedTime, fontSize = 9.sp, color = Color(0xFF8E8E93))
        }
    }
}

@Composable
private fun LineBadgeMap(line: String) {
    Box(
        modifier = Modifier.size(width = 38.dp, height = 22.dp).clip(RoundedCornerShape(4.dp))
            .background(colorFromHex(LineColors.backgroundHex(line))),
        contentAlignment = Alignment.Center
    ) { Text(line, color = colorFromHex(LineColors.textHex(line)), fontSize = 11.sp, fontWeight = FontWeight.Bold) }
}

// ── Traffic Banner / Live Indicator / Filter Sheet ──────────────────────

@Composable
private fun TrafficBanner(
    subscribedLines: Set<String>,
    alerts: List<com.alertetcl.shared.models.TCLAlert>,
    lastUpdateMs: Long?,
    hasError: Boolean,
    modifier: Modifier = Modifier,
    onTap: () -> Unit
) {
    val majorOnNetwork = remember(alerts) {
        alerts.count { it.severity == com.alertetcl.shared.models.AlertSeverity.MAJOR }
    }
    val mySubAlerts = remember(alerts, subscribedLines) {
        alerts.filter { it.ligneCom in subscribedLines }
    }
    val mySubMajor = mySubAlerts.count { it.severity == com.alertetcl.shared.models.AlertSeverity.MAJOR }

    val (bg, fg, icon, title, subtitle) = when {
        hasError -> Quintuple(
            Color(0xFFFFF4E5), Color(0xFFFF9500),
            Icons.Filled.Warning,
            "Données partielles",
            "Certaines sources sont indisponibles"
        )
        mySubMajor > 0 -> Quintuple(
            Color(0xFFFFEBEE), Color(0xFFFF3B30),
            Icons.Filled.Warning,
            "$mySubMajor perturbation${if (mySubMajor > 1) "s" else ""} majeure${if (mySubMajor > 1) "s" else ""}",
            "Sur vos lignes abonnées"
        )
        mySubAlerts.isNotEmpty() -> Quintuple(
            Color(0xFFFFF8E1), Color(0xFFFF9500),
            Icons.Filled.NotificationsActive,
            "${mySubAlerts.size} info${if (mySubAlerts.size > 1) "s" else ""} trafic",
            "Sur vos lignes abonnées"
        )
        majorOnNetwork > 0 -> Quintuple(
            Color(0xFFFFF4E5), Color(0xFFFF9500),
            Icons.Filled.Warning,
            "$majorOnNetwork perturbation${if (majorOnNetwork > 1) "s" else ""} majeure${if (majorOnNetwork > 1) "s" else ""}",
            "Sur le réseau TCL"
        )
        else -> Quintuple(
            Color(0xFFE8F5E9), Color(0xFF34C759),
            Icons.Filled.CheckCircle,
            "Réseau fluide",
            "Aucune perturbation majeure"
        )
    }

    Surface(
        shape = RoundedCornerShape(14.dp),
        color = bg,
        shadowElevation = 4.dp,
        modifier = modifier.clickable { onTap() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier.size(32.dp).clip(CircleShape).background(fg),
                contentAlignment = Alignment.Center
            ) { Icon(icon, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1C1C1E))
                Text(subtitle, fontSize = 11.sp, color = Color(0xFF6E6E73))
            }
        }
    }
}

private data class Quintuple<A,B,C,D,E>(val a: A, val b: B, val c: C, val d: D, val e: E)

@Composable
private fun LiveIndicator(
    isLive: Boolean,
    isLoading: Boolean,
    lastUpdateMs: Long?,
    nowMs: Long,
    hasError: Boolean,
    onTap: () -> Unit
) {
    val dotColor = if (hasError) Color(0xFFFF9500) else Color(0xFF34C759)
    val labelColor = if (!isLive) Color(0xFF8E8E93) else if (hasError) Color(0xFFFF9500) else Color(0xFF34C759)
    Surface(
        shape = RoundedCornerShape(50),
        color = Color.White.copy(alpha = 0.92f),
        shadowElevation = 4.dp,
        modifier = Modifier.clickable { onTap() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(dotColor))
            Text(
                if (isLive) "LIVE" else "PAUSE",
                fontSize = 12.sp,
                fontWeight = FontWeight.Black,
                color = labelColor
            )
            if (isLoading) {
                androidx.compose.material3.CircularProgressIndicator(
                    modifier = Modifier.size(12.dp),
                    strokeWidth = 1.5.dp
                )
            } else if (lastUpdateMs != null) {
                val secs = ((15_000L - (nowMs - lastUpdateMs)).coerceAtLeast(0) / 1000L).toInt()
                Text("${secs}s", fontSize = 11.sp, color = Color(0xFF8E8E93))
            }
        }
    }
}

@Composable
private fun RefreshInfoSheet(lastUpdateMs: Long?) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier.size(44.dp).clip(CircleShape).background(Color(0xFF34C759).copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) { Icon(Icons.Filled.NotificationsActive, null, tint = Color(0xFF34C759), modifier = Modifier.size(20.dp)) }
            Column(modifier = Modifier.weight(1f)) {
                Text("Temps réel", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Text("Positions TCL en direct", fontSize = 12.sp, color = Color(0xFF8E8E93))
            }
        }
        HorizontalDivider()
        Row(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("15s", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color(0xFF34C759))
                Text("intervalle", fontSize = 11.sp, color = Color(0xFF8E8E93))
            }
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                val txt = lastUpdateMs?.let {
                    val s = (System.currentTimeMillis() - it) / 1000L
                    when {
                        s < 5 -> "à l'instant"
                        s < 60 -> "il y a ${s}s"
                        else -> "il y a ${s / 60}min"
                    }
                } ?: "—"
                Text(txt, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Text("dernière maj", fontSize = 11.sp, color = Color(0xFF8E8E93))
            }
        }
        HorizontalDivider()
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.CheckCircle, null, tint = Color(0xFF34C759), modifier = Modifier.size(16.dp))
            Text("Inutile de rafraîchir manuellement", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun FilterSheet(
    selectedTypes: Set<VehicleType>,
    onToggleType: (VehicleType) -> Unit,
    showLineTraces: Boolean,
    onToggleTraces: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Filtres", fontSize = 20.sp, fontWeight = FontWeight.Bold)

        Text("Types de véhicules", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF8E8E93))
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            VehicleType.entries.sortedBy { it.sortOrder }.forEach { type ->
                FilterChip(
                    selected = type in selectedTypes,
                    onClick = { onToggleType(type) },
                    label = { Text(type.displayName, fontSize = 12.sp) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = colorFromHex(type.clusterColorHex).copy(alpha = 0.25f)
                    )
                )
            }
        }

        HorizontalDivider()

        Text("Affichage", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF8E8E93))
        Surface(shape = RoundedCornerShape(12.dp), color = Color(0xFFF2F2F7), modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Tracés des lignes", fontSize = 14.sp, fontWeight = FontWeight.Medium)
                    Text("Affiche les itinéraires des lignes", fontSize = 11.sp, color = Color(0xFF8E8E93))
                }
                Switch(checked = showLineTraces, onCheckedChange = { onToggleTraces() })
            }
        }
        // Note: les arrêts s'affichent automatiquement au zoom (latitudeDelta ≤ 0.018),
        // comme sur iOS. Pas de toggle manuel.
        Spacer(Modifier.height(8.dp))
    }
}

private fun recenterOnUser(context: android.content.Context, map: MapLibreMap?) {
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
        org.maplibre.android.camera.CameraUpdateFactory.newCameraPosition(
            CameraPosition.Builder()
                .target(LatLng(loc.latitude, loc.longitude))
                .zoom(15.0)
                .build()
        )
    )
}

// ── Bitmap helpers ───────────────────────────────────────────────────────

private fun parseAndroidColor(hex: String): Int {
    val s = hex.removePrefix("#")
    return try { AndroidColor.parseColor(if (s.length == 6 || s.length == 8) "#$s" else "#888888") }
    catch (_: Exception) { AndroidColor.GRAY }
}

/**
 * Marqueur véhicule — cercle iOS-like (96×96 px).
 * Forme : disque coloré + bordure fine noire 15% + nom de ligne centré.
 * La flèche directionnelle est sur VEHICLES_ARROW_LAYER (ne tourne pas avec le texte).
 */
private fun vehicleMarkerBitmap(line: String): Bitmap {
    val density = android.content.res.Resources.getSystem().displayMetrics.density
    val bg = parseAndroidColor(LineColors.backgroundHex(line))
    val tx = parseAndroidColor(LineColors.textHex(line))
    // 40dp diameter so MapLibre (which divides by density) renders it as 40dp on screen
    val size = (40 * density).toInt().coerceAtLeast(1)
    val bmp  = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val cx = size / 2f; val cy = size / 2f; val radius = size / 2f - density
    canvas.drawCircle(cx, cy, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = bg; style = Paint.Style.FILL
    })
    canvas.drawCircle(cx, cy, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.argb(38, 0, 0, 0); style = Paint.Style.STROKE; strokeWidth = density
    })
    val textSize = when { line.length <= 2 -> 14f * density; line.length == 3 -> 11f * density; else -> 9f * density }
    canvas.drawText(line, cx, cy + textSize * 0.38f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = tx; this.textSize = textSize; textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT_BOLD
    })
    return bmp
}

/** Triangle directionnel (pointe vers le haut = nord), coloré avec la couleur de ligne. */
private fun bearingArrowBitmap(line: String): Bitmap {
    val density = android.content.res.Resources.getSystem().displayMetrics.density
    val bg = parseAndroidColor(LineColors.backgroundHex(line))
    // 14×10dp so MapLibre renders it at 14×10dp after dividing by density
    val w = (14 * density).toInt().coerceAtLeast(1)
    val h = (10 * density).toInt().coerceAtLeast(1)
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val path = android.graphics.Path()
    path.moveTo(w / 2f, 0f)
    path.lineTo(w.toFloat(), h.toFloat())
    path.lineTo(0f, h.toFloat())
    path.close()
    canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg; style = Paint.Style.FILL })
    return bmp
}

/**
 * Disque compact pour un arrêt (mode dezoom, latitudeDelta > 0.005).
 * Équivalent iOS : MergedStopAnnotationView.setCompact() — dot 9pt blanc + contour bleu.
 */
private fun stopCompactBitmap(): Bitmap {
    val density = 3f
    val size    = (9 * density).toInt()
    val bmp     = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas  = Canvas(bmp)
    val cx = size / 2f; val cy = size / 2f; val r = size / 2f - density
    canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; style = Paint.Style.FILL
    })
    canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.parseColor("#1976D2"); style = Paint.Style.STROKE; strokeWidth = density
    })
    return bmp
}

/**
 * Disque (11pt) + rangée de capsules de ligne colorées (mode zoom serré, latitudeDelta ≤ 0.005).
 * Équivalent iOS : MergedStopAnnotationView.setBadges()
 *
 * Layout (bitmap en pixels @3x) :
 *   ●           ← dot 11pt centré horizontalement
 *   gap 2pt
 *   [C26][T1]…  ← badges (hauteur 11pt, police 7.5pt bold, max 4 lignes)
 */
private fun stopBadgeBitmap(lines: List<String>): Bitmap {
    val density    = 3f
    val dotSizePx  = (11 * density).toInt()
    val badgeH     = (11 * density).toInt()
    val gapPx      = (2  * density).toInt()
    val hPadPx     = (3  * density).toInt()
    val spacingPx  = (2  * density).toInt()
    val textSizePx = 7.5f * density
    val cornerR    = badgeH / 2f

    val capped     = lines.take(4)
    val textPaint  = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.textSize = textSizePx; typeface = Typeface.DEFAULT_BOLD
    }

    val badgeWidths = capped.map { line ->
        (textPaint.measureText(line) + 2 * hPadPx).toInt()
    }
    val totalBadgeW = badgeWidths.sum() + spacingPx * (capped.size - 1).coerceAtLeast(0)
    val totalW      = maxOf(dotSizePx, totalBadgeW)
    // Top padding = badgeH + gap pour que le centre du dot = centre vertical du bitmap
    // (avec ICON_ANCHOR_CENTER, MapLibre place le centre du bitmap sur la coordonnée)
    val topPad = badgeH + gapPx
    val totalH = topPad + dotSizePx + gapPx + badgeH

    val bmp    = Bitmap.createBitmap(totalW, totalH, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)

    // ── Dot ──────────────────────────────────────────────────────────────
    val dotX = (totalW - dotSizePx) / 2f
    val cx   = dotX + dotSizePx / 2f
    val cy   = topPad + dotSizePx / 2f
    val r    = dotSizePx / 2f - density
    canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; style = Paint.Style.FILL
    })
    canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.parseColor("#1976D2"); style = Paint.Style.STROKE; strokeWidth = density
    })

    // ── Badges ────────────────────────────────────────────────────────────
    var x = ((totalW - totalBadgeW) / 2f).toInt()
    val y = (topPad + dotSizePx + gapPx).toFloat()

    for ((i, line) in capped.withIndex()) {
        val bw     = badgeWidths[i].toFloat()
        val bgCol  = parseAndroidColor(LineColors.backgroundHex(line))
        val txCol  = parseAndroidColor(LineColors.textHex(line))
        val border = LineColors.needsBorder(line)
        val rect   = RectF(x.toFloat(), y, x + bw, y + badgeH)

        canvas.drawRoundRect(rect, cornerR, cornerR,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgCol; style = Paint.Style.FILL })

        if (border) {
            canvas.drawRoundRect(rect, cornerR, cornerR,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = AndroidColor.parseColor("#C7C7CC")
                    style = Paint.Style.STROKE; strokeWidth = 1.5f
                })
        }

        val textY = y + badgeH / 2f + textSizePx * 0.35f
        canvas.drawText(line, x + bw / 2f, textY,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = txCol; this.textSize = textSizePx
                textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT_BOLD
            })

        x += (bw + spacingPx).toInt()
    }
    return bmp
}

