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
import android.os.Build
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.gestures.detectVerticalDragGestures
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
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
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
// import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.IconButton
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import com.alertetcl.shared.models.VehicleType
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.alertetcl.shared.services.BusTrackerService
import com.alertetcl.shared.services.WikimediaService
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.BusLine
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.MergedStop
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.models.StopMergingEngine
import com.alertetcl.shared.models.TransitLine
import com.alertetcl.shared.models.TransportMode
// import com.alertetcl.android.data.WidgetSelection
import com.alertetcl.shared.models.AnimatedVehicle
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.android.ui.theme.StatusWarning
import com.alertetcl.android.ui.theme.StatusSuccess
import com.alertetcl.shared.services.BusLineService
import com.alertetcl.shared.services.TransitLineService
import com.alertetcl.shared.services.TransitStopService
import com.alertetcl.shared.viewmodels.LiveVehiclesViewModel
import com.google.gson.JsonObject
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.location.modes.CameraMode
import org.maplibre.android.location.modes.RenderMode
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
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

// Tuiles OpenFreeMap — 100% gratuit, sans clé API
private const val STYLE_URL_LIBERTY = "https://tiles.openfreemap.org/styles/liberty"
private const val STYLE_URL_DARK    = "https://tiles.openfreemap.org/styles/fiord"

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

private const val METRO_SRC       = "metro-src"
private const val TRAM_SRC        = "tram-src"
private const val BUS_C_SRC       = "bus-c-src"
private const val BUS_SRC         = "bus-src"
private const val VEHICLES_SRC    = "vehicles-src"
private const val STOPS_SRC       = "stops-src"
private const val METRO_LAYER     = "metro-layer"
private const val TRAM_LAYER      = "tram-layer"
private const val BUS_C_LAYER     = "bus-c-layer"
private const val BUS_LAYER       = "bus-layer"
private const val VEHICLES_LAYER  = "vehicles-layer"
private const val VEHICLES_ARROW_LAYER = "vehicles-arrow-layer"
private const val STOPS_LAYER       = "stops-layer"        // CircleLayer mode compact
private const val STOPS_BADGE_LAYER = "stops-badge-layer"  // SymbolLayer mode badges (zoom serré)

// Précompilé une seule fois — réutilisé dans les LaunchedEffect (parité iOS : aucune allocation par tick)
private val ICON_KEY_REGEX = Regex("[^A-Za-z0-9]")

@Composable
private fun rememberMapView(): MapView {
    val context = LocalContext.current
    // textureMode(true) = TextureView = obligatoire sur Samsung One UI 4.x (Android 12).
    // Le compositor Samsung crash avec SurfaceView ("Z-order hole punch") dans Compose.
    // Sur émulateur : pas de Samsung → SurfaceView (défaut, plus rapide, pas de GPU copy en trop).
    // Sur émulateur : density 420 dpi → pixelRatio ~2.6 → MapLibre charge ~7× trop de tuiles.
    //   On force pixelRatio=1.0 sur émulateur pour un rendu fluide.
    val isEmulator = Build.FINGERPRINT.startsWith("generic") ||
                     Build.FINGERPRINT.contains("emulator") ||
                     Build.MODEL.contains("Emulator") ||
                     Build.MODEL.contains("Android SDK")
    val isSamsung = Build.MANUFACTURER.equals("samsung", ignoreCase = true)
    val pixelRatio = if (isEmulator) 1.0f else context.resources.displayMetrics.density
    val mapView = remember {
        MapView(context, MapLibreMapOptions.createFromAttributes(context)
            .textureMode(!isEmulator && isSamsung)
            .pixelRatio(pixelRatio))
    }
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
    val androidVm: LiveMapAndroidViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
    val vm = androidVm.vm
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
            // vm.dispose() géré par LiveMapAndroidViewModel.onCleared()
        }
    }
    val vehicles     by vm.vehicles.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val isLoading    by vm.isLoading.collectAsState()
    val vehiclesError by vm.errorMessage.collectAsState()
    val isLive       by vm.isLive.collectAsState()
    val lastUpdateMs by vm.lastUpdateEpochMs.collectAsState()

    // Alertes pour le bandeau trafic en haut
    val alertsAndroidVm: AlertsAndroidViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
    val alertsVm = alertsAndroidVm.alertsVm
    DisposableEffect(Unit) {
        alertsVm.startPolling()
        onDispose {
            // alertsVm.dispose() géré par AlertsAndroidViewModel.onCleared()
        }
    }
    val alerts by alertsVm.alerts.collectAsState()
    val alertsError by alertsVm.errorMessage.collectAsState()

    val store = remember { com.alertetcl.android.data.FavoritesStore(context) }
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())
    val scope = rememberCoroutineScope()
    val selectedLines by store.selectedLiveLines.collectAsState(initial = emptySet())
    val availableLines = remember(vehicles) {
        vehicles
            .distinctBy { it.lineName }
            .sortedWith(compareBy({ it.vehicleType.sortOrder }, { it.lineName.toIntOrNull() ?: Int.MAX_VALUE }, { it.lineName }))
            .map { it.lineName }
    }
    val showBusTraces   by store.showBusTraces.collectAsState(initial = false)
    val showTramTraces  by store.showTramTraces.collectAsState(initial = true)
    val showMetroTraces by store.showMetroTraces.collectAsState(initial = true)
    val isDark = isSystemInDarkTheme()
    var isSatellite    by remember { mutableStateOf(false) }
    var bannerCollapsed by remember { mutableStateOf(false) }

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

    val filteredVehicles by remember {
        derivedStateOf { vehicles.filter { it.vehicleType in selectedTypes && (selectedLines.isEmpty() || it.lineName in selectedLines) } }
    }

    // MapLibre state
    var mapLibreMap by remember { mutableStateOf<MapLibreMap?>(null) }
    var mapStyle    by remember { mutableStateOf<Style?>(null) }
    // Sérialise les appels GL init (addSource/addLayer) — évite la saturation du GL thread au démarrage
    val glInitMutex        = remember { Mutex() }
    val vehiclesLayerReady = remember { mutableStateOf(false) }

    // Stable mutable refs lisibles depuis les callbacks non-composables (click handler)
    val vehiclesRef    = remember { mutableStateOf<List<Vehicle>>(emptyList()) }
    val mergedStopsRef = remember { mutableStateOf<List<MergedStop>>(emptyList()) }
    vehiclesRef.value  = filteredVehicles
    // StopMergingEngine.merge est mémoïsé — recalculé uniquement si stops.value change
    val mergedStops = remember(stops.value) { StopMergingEngine.merge(stops.value) }
    LaunchedEffect(mergedStops) { mergedStopsRef.value = mergedStops }

    // Caches pour la boucle tick 100 ms — zéro allocation Gson par tick
    val vehiclePropsCache = remember { HashMap<String, String>() }
    val vehicleArrowCache = remember { HashMap<String, String>() }
    val tickSb            = remember { StringBuilder(8192) }

    // Selection state
    val selectedVehicleId = remember { mutableStateOf<String?>(null) }
    val selectedStop      = remember { mutableStateOf<MergedStop?>(null) }

    // Bottom sheet flags
    var showAlertsSheet by remember { mutableStateOf(false) }
    var showFilterSheet by remember { mutableStateOf(false) }
    var showErrorsSheet by remember { mutableStateOf(false) }
    var showRefreshInfo by remember { mutableStateOf(false) }

    // Permission location pour le FAB localisation
    val locationPermLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            // Activer le composant localisation si ce n'est pas encore fait
            // (permission accordée pendant que l'appli tournait déjà)
            val map = mapLibreMap
            val style = map?.style
            if (map != null && style != null) enableLocationComponent(context, map, style)
            recenterOnUser(context, mapLibreMap)
        }
    }

    val mapView = rememberMapView()

    // Filtres actifs (parité iOS hasActiveFilters — les arrêts sont automatiques, pas un filtre)
    val hasActiveFilters = selectedTypes.size != VehicleType.entries.size ||
        showBusTraces || !showTramTraces || !showMetroTraces ||
        selectedLines.isNotEmpty()

    // ── UI ────────────────────────────────────────────────────────────────
    Box(modifier = Modifier.fillMaxSize()) {

        // Map
        AndroidView(
            factory = { _ ->
                mapView.also { mv ->
                    mv.getMapAsync { map ->
                        mapLibreMap = map
                        map.uiSettings.isLogoEnabled              = false
                        map.uiSettings.isAttributionEnabled       = false
                        map.uiSettings.isCompassEnabled           = false
                        map.uiSettings.isRotateGesturesEnabled    = false
                        map.cameraPosition = CameraPosition.Builder()
                            .target(LatLng(45.764043, 4.835659))
                            .zoom(12.5)
                            .build()
                        map.addOnMapClickListener { latLng ->
                            val screen = map.projection.toScreenLocation(latLng)
                            val pt = PointF(screen.x, screen.y)
                            val vf = map.queryRenderedFeatures(pt, VEHICLES_LAYER)
                            if (vf.isNotEmpty()) {
                                selectedVehicleId.value = vf[0].getStringProperty("id")
                                return@addOnMapClickListener true
                            }
                            val sf = map.queryRenderedFeatures(pt, STOPS_LAYER, STOPS_BADGE_LAYER)
                            if (sf.isNotEmpty()) {
                                val sid = sf[0].getStringProperty("id")
                                selectedStop.value = mergedStopsRef.value.find { it.id == sid }
                                return@addOnMapClickListener true
                            }
                            false
                        }
                        map.setStyle(Style.Builder().fromUri(if (isDark) STYLE_URL_DARK else STYLE_URL_LIBERTY)) { style ->
                            enableLocationComponent(context, map, style)
                            mapStyle = style
                        }
                    }
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Switch base style when satellite toggled (re-applies layers via mapStyle observer)
        LaunchedEffect(isSatellite, isDark) {
            val map = mapLibreMap ?: return@LaunchedEffect
            val builder = if (isSatellite) Style.Builder().fromJson(STYLE_JSON_SATELLITE)
                          else if (isDark)  Style.Builder().fromUri(STYLE_URL_DARK)
                          else              Style.Builder().fromUri(STYLE_URL_LIBERTY)
            vehiclesLayerReady.value = false
            mapStyle = null
            map.setStyle(builder) { style ->
                enableLocationComponent(context, map, style)
                mapStyle = style
            }
        }

        // ── Top: Traffic Banner ───────────────────────────────────────────
        AnimatedVisibility(
            visible = !bannerCollapsed,
            enter = slideInVertically(initialOffsetY = { -it }) + fadeIn(),
            exit  = slideOutVertically(targetOffsetY = { -it }) + fadeOut(),
            modifier = Modifier
                .align(Alignment.TopCenter)
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .fillMaxWidth()
        ) {
            var dragOffsetY by remember { mutableFloatStateOf(0f) }
            TrafficBanner(
                subscribedLines = favorites,
                alerts = alerts,
                lastUpdateMs = lastUpdateMs,
                hasError = vehiclesError != null || alertsError != null,
                modifier = Modifier
                    .fillMaxWidth()
                    .pointerInput(Unit) {
                        detectVerticalDragGestures(
                            onVerticalDrag = { _, delta -> dragOffsetY += delta },
                            onDragEnd = {
                                if (dragOffsetY < -40f) bannerCollapsed = true
                                dragOffsetY = 0f
                            },
                            onDragCancel = { dragOffsetY = 0f }
                        )
                    },
                onTap = { showAlertsSheet = true }
            )
        }
        if (bannerCollapsed) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .statusBarsPadding()
                    .padding(top = 8.dp)
                    .clip(RoundedCornerShape(50))
                    .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.92f))
                    .clickable { bannerCollapsed = false }
                    .padding(horizontal = 14.dp, vertical = 4.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.KeyboardArrowDown, null,
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // ── Bottom-left: Live Indicator ──────────────────────────────────
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .navigationBarsPadding()
                .padding(bottom = 96.dp, start = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (vehiclesError != null || alertsError != null) {
                Surface(
                    shape = RoundedCornerShape(50),
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    shadowElevation = 4.dp,
                    modifier = Modifier.clickable { showErrorsSheet = true }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Filled.Warning, null, tint = StatusWarning, modifier = Modifier.size(14.dp))
                        val n = (if (vehiclesError != null) 1 else 0) + (if (alertsError != null) 1 else 0)
                        Text("$n source${if (n > 1) "s" else ""} en erreur", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
                    }
                }
            }
            LiveIndicator(
                isLive = isLive,
                isLoading = isLoading,
                lastUpdateMs = lastUpdateMs,
                hasError = vehiclesError != null,
                onTap = { showRefreshInfo = true }
            )
        }

        // ── Bottom-right: 3 FABs (satellite, filters, location) ─────────
        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .navigationBarsPadding()
                .padding(bottom = 96.dp, end = 16.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            CircleFab(
                icon = Icons.Filled.Public, contentDesc = "Vue satellite",
                tint = if (isSatellite) StatusWarning else MaterialTheme.colorScheme.onSurface,
                onClick = { isSatellite = !isSatellite }
            )
            CircleFab(
                icon = Icons.Filled.FilterList, contentDesc = "Filtres",
                tint = if (hasActiveFilters) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                onClick = { showFilterSheet = true }
            )
            CircleFab(
                icon = Icons.Filled.MyLocation, contentDesc = "Ma position",
                tint = MaterialTheme.colorScheme.primary,
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

    // Line traces — z-order bottom → top: bus → Bus C → tram → métro/funi
    LaunchedEffect(mapStyle, showBusTraces, showTramTraces, showMetroTraces, transitLines.value, busLines.value, selectedLines) {
        val style = mapStyle ?: return@LaunchedEffect

        // Capture immutable snapshots avant de switcher sur Default — évite les lectures de
        // Compose State depuis un thread non-Main (undefined behavior dans le snapshot system).
        val capturedBus     = busLines.value
        val capturedTransit = transitLines.value
        val capturedFilters = selectedLines
        val capturedBusTraces   = showBusTraces
        val capturedTramTraces  = showTramTraces
        val capturedMetroTraces = showMetroTraces

        // Sérialisation GeoJSON incluse dans le withContext(Default) — aucun JSON sur Main
        fun addOrUpdate(src: String, layer: String, geojson: String, width: Float) {
            if (style.getSource(src) == null) {
                style.addSource(GeoJsonSource(src, geojson))
                val lineLayer = LineLayer(layer, src).withProperties(
                    PropertyFactory.lineColor(Expression.get("color")),
                    PropertyFactory.lineWidth(width),
                    PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                    PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)
                )
                if (style.getLayer(VEHICLES_ARROW_LAYER) != null)
                    style.addLayerBelow(lineLayer, VEHICLES_ARROW_LAYER)
                else
                    style.addLayer(lineLayer)
            } else {
                style.getSourceAs<GeoJsonSource>(src)?.setGeoJson(geojson)
            }
        }

        // Construction des GeoJSON en string directe — évite d'allouer des milliers d'objets Point MapLibre
        val allGeoJsons = withContext(Dispatchers.Default) {
            listOf(
                if (capturedBusTraces)   buildLinesGeoJson(capturedBus.filter { !it.name.startsWith("C") }, capturedFilters) { toMapColor(LineColors.routeStrokeHex(it)) }   else EMPTY_FEATURE_COLLECTION,
                if (capturedBusTraces)   buildLinesGeoJson(capturedBus.filter {  it.name.startsWith("C") }, capturedFilters) { toMapColor(LineColors.routeStrokeHex(it)) }   else EMPTY_FEATURE_COLLECTION,
                if (capturedTramTraces)  buildTransitLinesGeoJson(capturedTransit.filter {  it.familyTransport.contains("tram", ignoreCase = true) }, capturedFilters)  else EMPTY_FEATURE_COLLECTION,
                if (capturedMetroTraces) buildTransitLinesGeoJson(capturedTransit.filter { !it.familyTransport.contains("tram", ignoreCase = true) }, capturedFilters) else EMPTY_FEATURE_COLLECTION
            )
        }

        glInitMutex.withLock {
            addOrUpdate(BUS_SRC,   BUS_LAYER,   allGeoJsons[0], 4f)
            addOrUpdate(BUS_C_SRC, BUS_C_LAYER, allGeoJsons[1], 4f)
            addOrUpdate(TRAM_SRC,  TRAM_LAYER,  allGeoJsons[2], 8f)
            addOrUpdate(METRO_SRC, METRO_LAYER, allGeoJsons[3], 8f)
        }
    }

    // Vehicle markers
    LaunchedEffect(mapStyle, filteredVehicles) {
        val style = mapStyle ?: return@LaunchedEffect
        val current = filteredVehicles

        // Register circle body + dot + arrow icons (once per unique line)
        if (style.getImage("no_arrow") == null)
            style.addImage("no_arrow", Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))

        // Collecte les lignes manquantes sur Main (style.getImage doit rester sur Main),
        // puis construit les bitmaps Canvas sur Default pour ne pas bloquer le UI thread.
        val linesToBuild = current.map { it.lineName }.distinct()
            .filter { style.getImage(vehicleIconKey(it)) == null }
        if (linesToBuild.isNotEmpty()) {
            val newBitmaps = withContext(Dispatchers.Default) {
                linesToBuild.flatMap { line ->
                    listOf(
                        vehicleIconKey(line)  to vehicleMarkerBitmap(line),
                        vehicleDotKey(line)   to vehicleDotBitmap(line),
                        vehicleArrowKey(line) to bearingArrowBitmap(line)
                    )
                }
            }
            newBitmaps.forEach { (key, bmp) -> style.addImage(key, bmp) }
        }

        // Rebuild static caches — runs once per 15s poll, never per 100ms tick
        vehiclePropsCache.clear()
        vehicleArrowCache.clear()
        for (v in current) {
            vehiclePropsCache[v.id] = buildVehicleStaticProps(v)
            vehicleArrowCache[v.id] = vehicleArrowKey(v.lineName)
        }

        val nowSec   = System.currentTimeMillis() / 1000.0
        val features = current.map { v -> buildVehicleFeature(v, vm.animatedVehicleFor(v.id), nowSec) }

        if (style.getSource(VEHICLES_SRC) == null) {
            glInitMutex.withLock {
                if (style.getSource(VEHICLES_SRC) == null) {
                    style.addSource(GeoJsonSource(VEHICLES_SRC, FeatureCollection.fromFeatures(features)))
                    // Layer 1 : flèche orbitale — sous le corps (z-index inférieur), masquée en dezoom
                    style.addLayer(SymbolLayer(VEHICLES_ARROW_LAYER, VEHICLES_SRC).withProperties(
                        PropertyFactory.iconImage(
                            Expression.step(
                                Expression.zoom(),
                                Expression.literal("no_arrow"),
                                Expression.literal(13.5), Expression.get("arrow_icon")
                            )
                        ),
                        PropertyFactory.iconAnchor(Property.ICON_ANCHOR_BOTTOM),
                        PropertyFactory.iconRotate(Expression.toNumber(Expression.get("bearing"))),
                        PropertyFactory.iconRotationAlignment(Property.ICON_ROTATION_ALIGNMENT_VIEWPORT),
                        PropertyFactory.iconAllowOverlap(true),
                        PropertyFactory.iconIgnorePlacement(true),
                        PropertyFactory.iconSize(1f)
                    ))
                    // Layer 2 : corps — au-dessus de la flèche, point coloré en dezoom (< 13.5)
                    style.addLayer(SymbolLayer(VEHICLES_LAYER, VEHICLES_SRC).withProperties(
                        PropertyFactory.iconImage(
                            Expression.step(
                                Expression.zoom(),
                                Expression.get("dot_icon"),
                                Expression.literal(13.5), Expression.get("icon")
                            )
                        ),
                        PropertyFactory.iconAllowOverlap(true),
                        PropertyFactory.iconIgnorePlacement(true),
                        PropertyFactory.iconSize(1f)
                    ))
                }
            }
            vehiclesLayerReady.value = true
        } else {
            style.getSourceAs<GeoJsonSource>(VEHICLES_SRC)
                ?.setGeoJson(buildVehicleGeoJson(current, vehiclePropsCache, vehicleArrowCache, vm, nowSec, tickSb))
        }
    }

    // Interpolation continue — 100 ms si transition active, 500 ms si stable (économie CPU).
    // Fixes : (1) race condition → attend que VEHICLES_SRC existe ;
    //         (2) StringBuilder + cache statique → zéro Gson dans le hot path ;
    //         (3) setGeoJson(String) → supprime la double sérialisation MapLibre.
    LaunchedEffect(mapStyle) {
        val style = mapStyle ?: return@LaunchedEffect
        // Attend que l'init GL vehicles soit terminée — suspend proprement, zéro polling.
        snapshotFlow { vehiclesLayerReady.value }.first { it }
        val source = style.getSourceAs<GeoJsonSource>(VEHICLES_SRC) ?: return@LaunchedEffect
        while (true) {
            val nowSec  = System.currentTimeMillis() / 1000.0
            val current = vehiclesRef.value
            if (current.isEmpty()) { kotlinx.coroutines.delay(100); continue }
            // Skip si aucune transition active → 500 ms au lieu de 100 ms
            if (!vm.hasAnyActiveTransition(nowSec)) { kotlinx.coroutines.delay(500); continue }
            source.setGeoJson(
                buildVehicleGeoJson(current, vehiclePropsCache, vehicleArrowCache, vm, nowSec, tickSb)
            )
            kotlinx.coroutines.delay(100)
        }
    }

    // Stops — chargés une seule fois par (mapStyle, données stops).
    // La visibilité zoom est gérée nativement par withMinZoom sur les layers :
    //   zoom ≥ 14 → cercles compacts (parité iOS latitudeDelta ≈ 0.018)
    //   zoom ≥ 16 → badges de ligne  (parité iOS latitudeDelta ≈ 0.005)
    // Les icônes sont pré-construites en un seul bloc sur Default — le cache GPU
    // ne croît plus après le premier chargement (fini le freeze par accumulation).
    LaunchedEffect(mapStyle, mergedStops) {
        val style = mapStyle ?: return@LaunchedEffect
        if (mergedStops.isEmpty()) return@LaunchedEffect

        // Étape 1 (Default) : toutes les métadonnées + GeoJSON complet en un seul passage
        val (geojson, allEntries) = withContext(Dispatchers.Default) {
            val entries = mergedStops.map { stop ->
                val lines = stop.allLines.filter { !it.startsWith("JD", ignoreCase = true) }
                val tier  = StopTier.from(lines)
                val pl    = StopTier.primaryLine(lines)
                val fill  = if (tier == StopTier.METRO && pl != null) LineColors.backgroundHex(pl) else tier.fillHex
                val key   = if (lines.isNotEmpty())
                    "stop_${tier.name}_${pl ?: ""}_" + lines.take(4).joinToString("_")
                else "stop_dot_${tier.name}_${pl ?: ""}"
                StopEntry(stop.id, stop.coordinate.longitude, stop.coordinate.latitude,
                          fill, tier.compactR, tier.compactSW, key, lines, tier, pl)
            }
            val json = FeatureCollection.fromFeatures(entries.map { e ->
                Feature.fromGeometry(
                    Point.fromLngLat(e.lon, e.lat),
                    JsonObject().apply {
                        addProperty("id",         e.id)
                        addProperty("fill_color", e.fillHex)
                        addProperty("circle_r",   e.circleR)
                        addProperty("stroke_w",   e.strokeW)
                        addProperty("icon",       e.iconKey)
                    }
                )
            }).toJson()
            json to entries
        }

        // Étape 2 (Main) : enregistrement des bitmaps manquants — style.getImage exige Main
        val missing = allEntries.distinctBy { it.iconKey }
            .filter { style.getImage(it.iconKey) == null }
        if (missing.isNotEmpty()) {
            val built = withContext(Dispatchers.Default) {
                missing.associate { e ->
                    e.iconKey to if (e.visibleLines.isNotEmpty())
                        stopBadgeBitmap(e.visibleLines, e.tier, e.primaryLine)
                    else stopCompactBitmap(e.tier, e.primaryLine)
                }
            }
            built.forEach { (key, bmp) -> style.addImage(key, bmp) }
        }

        // Étape 3 (Main) : source + layers MapLibre
        if (style.getSource(STOPS_SRC) == null) {
            glInitMutex.withLock {
                if (style.getSource(STOPS_SRC) == null) {
                    style.addSource(GeoJsonSource(STOPS_SRC, geojson))
                    val circleLayer = CircleLayer(STOPS_LAYER, STOPS_SRC).withProperties(
                            PropertyFactory.circleColor(Expression.get("fill_color")),
                            PropertyFactory.circleStrokeColor("#FFFFFF"),
                            PropertyFactory.circleRadius(Expression.toNumber(Expression.get("circle_r"))),
                            PropertyFactory.circleStrokeWidth(Expression.toNumber(Expression.get("stroke_w")))
                        )
                    circleLayer.setMinZoom(14f)
                    circleLayer.setMaxZoom(16f) // exclusif : masqué quand badgeLayer prend le relais
                    val badgeLayer = SymbolLayer(STOPS_BADGE_LAYER, STOPS_SRC).withProperties(
                            PropertyFactory.iconImage(Expression.get("icon")),
                            PropertyFactory.iconAllowOverlap(true),
                            PropertyFactory.iconIgnorePlacement(true),
                            PropertyFactory.iconAnchor(Property.ICON_ANCHOR_CENTER)
                        )
                    badgeLayer.setMinZoom(16f)
                    if (style.getLayer(VEHICLES_LAYER) != null) {
                        style.addLayerBelow(circleLayer, VEHICLES_ARROW_LAYER)
                        style.addLayerBelow(badgeLayer, VEHICLES_ARROW_LAYER)
                    } else {
                        style.addLayer(circleLayer)
                        style.addLayer(badgeLayer)
                    }
                }
            }
        } else {
            style.getSourceAs<GeoJsonSource>(STOPS_SRC)?.setGeoJson(geojson)
        }
    }

    // ── Bottom sheets ───────────────────────────────────────────────────

    filteredVehicles.find { it.id == selectedVehicleId.value }?.let { v ->
        ModalBottomSheet(onDismissRequest = { selectedVehicleId.value = null }, sheetState = rememberModalBottomSheetState(), contentWindowInsets = { WindowInsets.systemBars }) {
            VehicleDetailSheet(v)
        }
    }
    selectedStop.value?.let { stop ->
        ModalBottomSheet(onDismissRequest = { selectedStop.value = null }, sheetState = rememberModalBottomSheetState(), contentWindowInsets = { WindowInsets.systemBars }) {
        MergedStopDetailSheet(stop)
        }
    }
    if (showAlertsSheet) {
        ModalBottomSheet(onDismissRequest = { showAlertsSheet = false }, sheetState = rememberModalBottomSheetState(), contentWindowInsets = { WindowInsets.systemBars }) {
            Box(Modifier.fillMaxSize()) { com.alertetcl.android.ui.alerts.AlertsScreen(viewModel = alertsVm) }
        }
    }
    if (showFilterSheet) {
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            sheetState = rememberModalBottomSheetState(),
            contentWindowInsets = { WindowInsets.systemBars }
        ) {
            FilterSheet(
                selectedTypes = selectedTypes,
                onToggleType = { vm.toggleType(it) },
                selectedLines = selectedLines,
                onToggleLine = { line ->
                    scope.launch {
                        store.setSelectedLiveLines(
                            if (line in selectedLines) selectedLines - line else selectedLines + line
                        )
                    }
                },
                availableLines = availableLines,
                favorites = favorites,
                onToggleFavorite = { scope.launch { store.toggleFavoriteLine(it) } },
                showBusTraces = showBusTraces,
                onToggleBusTraces = { scope.launch { store.setShowBusTraces(!showBusTraces) } },
                showTramTraces = showTramTraces,
                onToggleTramTraces = { scope.launch { store.setShowTramTraces(!showTramTraces) } },
                showMetroTraces = showMetroTraces,
                onToggleMetroTraces = { scope.launch { store.setShowMetroTraces(!showMetroTraces) } },
                hasActiveFilters = hasActiveFilters,
                onClearFilters = {
                    VehicleType.entries.filter { it != VehicleType.METRO && it !in vm.selectedTypes.value }.forEach { vm.toggleType(it) }
                    scope.launch {
                        store.setSelectedLiveLines(emptySet())
                        store.setShowBusTraces(false)
                        store.setShowTramTraces(true)
                        store.setShowMetroTraces(true)
                    }
                },
                vehicles = vehicles
            )
        }
    }
    if (showRefreshInfo) {
        ModalBottomSheet(onDismissRequest = { showRefreshInfo = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), contentWindowInsets = { WindowInsets.systemBars }) {
            RefreshInfoSheet(lastUpdateMs = lastUpdateMs)
        }
    }
    if (showErrorsSheet) {
        ModalBottomSheet(onDismissRequest = { showErrorsSheet = false }, sheetState = rememberModalBottomSheetState(), contentWindowInsets = { WindowInsets.systemBars }) {
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
    var vehicleModel by remember { mutableStateOf<String?>(null) }
    var vehiclePhotos by remember { mutableStateOf<List<String>>(emptyList()) }
    var selectedPhoto by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(v.fleetNumber) {
        vehicleModel = v.fleetNumber?.let { BusTrackerService.shared.fetchVehicleModel(it) }
        vehicleModel?.let { vehiclePhotos = WikimediaService.shared.fetchPhotoUrls(it) }
    }
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
            color = MaterialTheme.colorScheme.surfaceContainerLow,
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
                    shape = MaterialTheme.shapes.large,
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
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        letterSpacing = 0.5.sp
                    )
                    val cleanDest = v.destination.trim()
                    if (cleanDest.isNotEmpty() && !cleanDest.contains(":") && cleanDest.length < 60) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Icon(Icons.Filled.ArrowForward, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(12.dp))
                            Text(cleanDest, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, maxLines = 1)
                        }
                    }
                    // Pastille retard
                    val delayColor = when {
                        v.isDelayed -> StatusWarning
                        v.isEarly   -> MaterialTheme.colorScheme.primary
                        else        -> StatusSuccess
                    }
                    Surface(shape = RoundedCornerShape(50), color = delayColor.copy(alpha = 0.12f)) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(Icons.Filled.AccessTime, null, tint = delayColor, modifier = Modifier.size(11.dp))
                            Text(v.delayFormatted, color = delayColor, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }

        // ── Timeline prochain arrêt ──
        v.nextStop?.let { ns ->
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                shadowElevation = 3.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
                    Text(
                        text = "DERNIER ARRÊT",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                            }
                            val arrivalEpoch = ns.aimedArrivalTimeEpoch ?: ns.aimedDepartureTimeEpoch
                            if (arrivalEpoch != null) {
                                val time = java.time.Instant.ofEpochSecond(arrivalEpoch)
                                    .atZone(java.time.ZoneId.systemDefault())
                                val timeStr = java.time.format.DateTimeFormatter.ofPattern("HH:mm").format(time)
                                val minsUntil = (arrivalEpoch - System.currentTimeMillis() / 1000L) / 60L
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

        // ── Véhicule ──
        v.fleetNumber?.let { fleet ->
            val uriHandler = LocalUriHandler.current
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerLow,
                shadowElevation = 3.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Column {
                    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
                        Text(
                            text = "VÉHICULE",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            letterSpacing = 0.5.sp
                        )
                        Spacer(Modifier.height(12.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = accentColor.copy(alpha = 0.12f),
                                modifier = Modifier.size(40.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
                                    Icon(vehicleTypeIcon(v.vehicleType), null, tint = accentColor, modifier = Modifier.size(18.dp))
                                }
                            }
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(fleet, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                                vehicleModel?.let { model ->
                                    Text(model, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("Source : bus-tracker.fr", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f))
                                }
                                Text(
                                    "Numéro de parc",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                                )
                            }
                        }
                    }
                    if (vehicleModel != null) {
                        vehicleModel?.let { model ->
                            val encodedQuery = java.net.URLEncoder.encode("$model TCL SYTRAL", "UTF-8")
                            if (vehiclePhotos.isEmpty()) {
                                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                                Text(
                                    text = "Photos de ce véhicule ↗",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { try { uriHandler.openUri("https://www.google.com/search?q=$encodedQuery&tbm=isch") } catch (_: Exception) {} }
                                        .padding(horizontal = 16.dp, vertical = 10.dp)
                                )
                            }
                        }
                    }
                    if (vehiclePhotos.isNotEmpty()) {
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                        Spacer(Modifier.height(8.dp))
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(vehiclePhotos) { url ->
                                WikimediaPhoto(
                                    url = url,
                                    modifier = Modifier
                                        .width(180.dp)
                                        .height(112.dp)
                                        .clip(RoundedCornerShape(10.dp))
                                        .clickable { selectedPhoto = url }
                                )
                            }
                        }
                        Text(
                            text = "Source : Wikimedia Commons (CC-BY-SA)",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                        )
                        Spacer(Modifier.height(4.dp))
                    }
                }
            }
        }

        // ── Footer mis à jour ──
        v.recordedAtEpoch?.let { epoch ->
            val timeStr = java.time.format.DateTimeFormatter.ofPattern("HH:mm").format(
                java.time.Instant.ofEpochSecond(epoch).atZone(java.time.ZoneId.systemDefault())
            )
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.Public, null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.size(11.dp))
                Spacer(Modifier.width(5.dp))
                Text("Mis à jour à $timeStr", fontSize = 10.sp, color = MaterialTheme.colorScheme.outline)
            }
        }
    }

    // ── Fullscreen photo viewer ──
    selectedPhoto?.let { url ->
        val context = LocalContext.current
        Dialog(
            onDismissRequest = { selectedPhoto = null },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black)
                    .clickable { selectedPhoto = null },
                contentAlignment = Alignment.Center
            ) {
                WikimediaPhoto(
                    url = url,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxWidth()
                )
                Text(
                    text = "Fermer",
                    color = Color.White,
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(16.dp)
                        .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                        .clickable { selectedPhoto = null }
                )
            }
        }
    }
}

private fun vehicleTypeIcon(type: VehicleType): androidx.compose.ui.graphics.vector.ImageVector = when (type) {
    VehicleType.BUS, VehicleType.TROLLEY -> Icons.Filled.DirectionsBus
    else -> Icons.Filled.Tram
}

/**
 * Charge une image Wikimedia via le client Ktor partagé (même stack réseau que l'API).
 * Coil échoue sur upload.wikimedia.org depuis Android — bypass complet du réseau Coil.
 * iOS utilise URLSession directement via SwiftUI AsyncImage : comportement équivalent.
 */
@Composable
private fun WikimediaPhoto(url: String, modifier: Modifier = Modifier, contentScale: ContentScale = ContentScale.Crop) {
    val bitmap by produceState<ImageBitmap?>(null, url) {
        value = withContext(Dispatchers.IO) {
            WikimediaService.shared.fetchImageBytes(url)
                ?.let { bytes ->
                    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                        ?.asImageBitmap()
                }
        }
    }
    Box(modifier, contentAlignment = Alignment.Center) {
        if (bitmap == null) {
            Box(
                Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surfaceContainerHigh),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp) }
        } else {
            Image(
                bitmap = bitmap!!,
                contentDescription = null,
                contentScale = contentScale,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}

// ── Bottom-sheet helpers ─────────────────────────────────────────────────

@Composable
private fun CircleFab(icon: androidx.compose.ui.graphics.vector.ImageVector, contentDesc: String,
                     tint: Color, onClick: () -> Unit) {
    SmallFloatingActionButton(
        onClick = onClick,
        shape = CircleShape,
        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
        contentColor = tint,
    ) {
        Icon(icon, contentDesc, modifier = Modifier.size(22.dp))
    }
}

private data class LineDirectionKey(val line: String, val direction: String)

@Composable
private fun MergedStopDetailSheet(stop: MergedStop) {
    val context = LocalContext.current
    // ── Widget (désactivé) ──
    // val widgetStore = remember { com.alertetcl.android.data.FavoritesStore(context) }
    // val widgetSelections by widgetStore.widgetSelections.collectAsState(initial = emptyList())
    // val isInWidget = stop.stops.any { member -> widgetSelections.any { it.stopId == member.id } }
    // var showWidgetSheet by remember { mutableStateOf(false) }
    // val lineDirections = remember(stop) {
    //     stop.stops.flatMap { member ->
    //         member.desserte.split(",").mapNotNull {
    //             val parts = it.split(":")
    //             if (parts.size >= 2) parts[0].trim() to parts[1].trim() else null
    //         }
    //     }.distinctBy { it.first + "|" + it.second }.sortedWith(compareBy({ it.first }, { it.second }))
    // }
    // val widgetDestinationMap = produceState<Map<String, String>>(initialValue = emptyMap(), stop) {
    //     val bus     = runCatching { BusLineService.shared.fetchLineTermini() }.getOrDefault(emptyMap())
    //     val transit = runCatching { TransitLineService.shared.fetchLineTermini() }.getOrDefault(emptyMap())
    //     value = bus + transit
    // }
    // val primaryStop = stop.stops.firstOrNull()
    // val scope = rememberCoroutineScope()
    var passagesKey by remember(stop.id) { mutableStateOf(0) }
    var passagesHadError by remember(stop.id) { mutableStateOf(false) }
    val passages = produceState<List<Passage>?>(initialValue = null, stop.id, passagesKey) {
        passagesHadError = false
        var anyError = false
        val all = coroutineScope {
            stop.stops.map { member ->
                async {
                    try {
                        TransitStopService.shared.fetchPassagesForStop(member.id)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        anyError = true
                        emptyList()
                    }
                }
            }.awaitAll()
        }.flatten().sortedBy { it.heurepassage }
        passagesHadError = anyError
        value = all
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
                        .background(MaterialTheme.colorScheme.primaryContainer),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Filled.Tram, null, tint = MaterialTheme.colorScheme.onPrimaryContainer, modifier = Modifier.size(28.dp))
                }
                Text(stop.nom, fontWeight = FontWeight.Bold, fontSize = 19.sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                if (stop.commune.isNotEmpty())
                    Text(stop.commune, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                if (stop.allLines.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        stop.allLines.take(6).forEach { line ->
                            com.alertetcl.android.ui.alerts.LineBadge(line, size = 28.dp, fontSize = 12.sp)
                        }
                        if (stop.allLines.size > 6) Text("+${stop.allLines.size - 6}", style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 4.dp))
                    }
                }
                if (stop.pmr) {
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Filled.Accessible, null, tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(14.dp))
                        Text("Accessible PMR", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))

        // ── Ajouter au widget (désactivé) ──
        // Button(
        //     onClick = {
        //         if (isInWidget) scope.launch {
        //             stop.stops.forEach { widgetStore.removeWidgetSelectionsForStop(it.id) }
        //         } else showWidgetSheet = true
        //     },
        //     modifier = Modifier.fillMaxWidth(),
        //     colors = ButtonDefaults.buttonColors(
        //         containerColor = if (isInWidget) StatusSuccess else MaterialTheme.colorScheme.primary
        //     )
        // ) {
        //     Icon(
        //         if (isInWidget) Icons.Filled.CheckCircle else Icons.Filled.AddCircle,
        //         contentDescription = null,
        //         modifier = Modifier.size(16.dp)
        //     )
        //     Spacer(Modifier.width(6.dp))
        //     Text(
        //         if (isInWidget) "Dans le widget" else "Ajouter au widget",
        //         fontWeight = FontWeight.SemiBold,
        //         style = MaterialTheme.typography.bodyMedium
        //     )
        // }
        // Spacer(Modifier.height(16.dp))

        // if (showWidgetSheet && !isInWidget) {
        //     Spacer(Modifier.height(4.dp))
        //     Text(
        //         "Choisir une ligne :",
        //         fontWeight = FontWeight.SemiBold,
        //         fontSize = 13.sp,
        //         color = MaterialTheme.colorScheme.onSurfaceVariant,
        //         modifier = Modifier.padding(bottom = 6.dp),
        //     )
        //     Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        //         lineDirections.forEach { (line, direction) ->
        //             val destLabel = widgetDestinationMap.value["${line}|${direction}"].takeUnless { it.isNullOrBlank() } ?: direction.ifBlank { "—" }
        //             Surface(
        //                 shape = RoundedCornerShape(12.dp),
        //                 color = MaterialTheme.colorScheme.surface,
        //                 tonalElevation = 1.dp,
        //                 modifier = Modifier.fillMaxWidth().clickable {
        //                     val stopId = primaryStop?.id ?: return@clickable
        //                     val sel = WidgetSelection(
        //                         id = "$stopId-$line-$direction",
        //                         stopId = stopId,
        //                         stopName = stop.nom,
        //                         lineName = line,
        //                         direction = direction,
        //                         destinationName = destLabel,
        //                     )
        //                     scope.launch { widgetStore.addWidgetSelection(sel) }
        //                     showWidgetSheet = false
        //                 }
        //             ) {
        //                 Row(
        //                     modifier = Modifier.padding(12.dp),
        //                     verticalAlignment = Alignment.CenterVertically,
        //                     horizontalArrangement = Arrangement.spacedBy(12.dp),
        //                 ) {
        //                     com.alertetcl.android.ui.alerts.LineBadge(line, size = 36.dp, fontSize = 14.sp)
        //                     Column(modifier = Modifier.weight(1f)) {
        //                         Text("Direction", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        //                         Text(
        //                             destLabel,
        //                             style = MaterialTheme.typography.bodyMedium, maxLines = 2
        //                         )
        //                     }
        //                 }
        //             }
        //         }
        //     }
        //     Spacer(Modifier.height(8.dp))
        // }

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    Icons.Filled.AccessTime, null,
                    tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(15.dp)
                )
                Text("Prochains passages", fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.primary)
            }
            IconButton(onClick = { passagesKey++ }, modifier = Modifier.size(28.dp)) {
                Icon(Icons.Filled.Refresh, "Rafraîchir les passages",
                    tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
            }
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
                        Text("Chargement des passages…", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            passagesHadError && groupedPassages.isEmpty() -> {
                Box(modifier = Modifier.fillMaxWidth().padding(vertical = 28.dp),
                    contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(
                            Icons.Filled.Warning, null,
                            tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(36.dp)
                        )
                        Text("Impossible de charger les passages", fontSize = 13.sp, fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                        TextButton(onClick = { passagesKey++ }) { Text("Réessayer") }
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
                            tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(36.dp)
                        )
                        Text("Aucun passage prévu", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            "Les horaires seront affichés quand des véhicules seront en approche",
                            style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
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
    Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp, shadowElevation = 1.dp,
        modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                com.alertetcl.android.ui.alerts.LineBadge(line, size = 32.dp, fontSize = 13.sp)
                Column(modifier = Modifier.weight(1f)) {
                    Text("Direction", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
    val bg = if (p.isRealTime) StatusSuccess.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surfaceVariant
    val accent = if (p.isRealTime) StatusSuccess else MaterialTheme.colorScheme.onSurfaceVariant
    Surface(shape = RoundedCornerShape(10.dp), color = bg) {
        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            Text(p.delaipassage.ifBlank { "--" }, fontSize = 13.sp,
                fontWeight = FontWeight.Bold, color = accent)
            Text(p.formattedTime, fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
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

    val (bg, fg, icon, title, subtitle, onBg) = when {
        hasError -> BannerState(
            MaterialTheme.colorScheme.tertiaryContainer, MaterialTheme.colorScheme.tertiary,
            Icons.Filled.Warning,
            "Données partielles",
            "Certaines sources sont indisponibles",
            MaterialTheme.colorScheme.onTertiaryContainer
        )
        mySubMajor > 0 -> BannerState(
            MaterialTheme.colorScheme.errorContainer, MaterialTheme.colorScheme.error,
            Icons.Filled.Warning,
            "$mySubMajor perturbation${if (mySubMajor > 1) "s" else ""} majeure${if (mySubMajor > 1) "s" else ""}",
            "Sur vos lignes abonnées",
            MaterialTheme.colorScheme.onErrorContainer
        )
        mySubAlerts.isNotEmpty() -> BannerState(
            MaterialTheme.colorScheme.tertiaryContainer, MaterialTheme.colorScheme.tertiary,
            Icons.Filled.NotificationsActive,
            "${mySubAlerts.size} info${if (mySubAlerts.size > 1) "s" else ""} trafic",
            "Sur vos lignes abonnées",
            MaterialTheme.colorScheme.onTertiaryContainer
        )
        majorOnNetwork > 0 -> BannerState(
            MaterialTheme.colorScheme.tertiaryContainer, MaterialTheme.colorScheme.tertiary,
            Icons.Filled.Warning,
            "$majorOnNetwork perturbation${if (majorOnNetwork > 1) "s" else ""} majeure${if (majorOnNetwork > 1) "s" else ""}",
            "Sur le réseau TCL",
            MaterialTheme.colorScheme.onTertiaryContainer
        )
        else -> BannerState(
            MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.primary,
            Icons.Filled.CheckCircle,
            "Réseau fluide",
            "Aucune perturbation majeure",
            MaterialTheme.colorScheme.onPrimaryContainer
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
                Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = onBg)
                Text(subtitle, style = MaterialTheme.typography.labelSmall, color = onBg.copy(alpha = 0.7f))
            }
        }
    }
}

private data class BannerState(val bg: Color, val fg: Color, val icon: ImageVector, val title: String, val subtitle: String, val onBg: Color)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LiveIndicator(
    isLive: Boolean,
    isLoading: Boolean,
    lastUpdateMs: Long?,
    hasError: Boolean,
    onTap: () -> Unit
) {
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) { kotlinx.coroutines.delay(1000); nowMs = System.currentTimeMillis() }
    }
    val dotColor = when {
        !isLive  -> MaterialTheme.colorScheme.onSurfaceVariant
        hasError -> StatusWarning
        else     -> StatusSuccess
    }
    val labelColor = dotColor

    // Surface toujours opaque — les tokens M3 surfaceContainer* sont des couleurs pleines
    val containerColor = MaterialTheme.colorScheme.surfaceContainerHigh

    val infiniteTransition = rememberInfiniteTransition(label = "livePulse")
    val dotAlpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.25f,
        animationSpec = infiniteRepeatable(
            animation = tween(700),
            repeatMode = RepeatMode.Reverse
        ),
        label = "dotAlpha"
    )

    Surface(
        onClick = onTap,
        shape = CircleShape,
        color = containerColor,
        shadowElevation = 3.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(dotColor.copy(alpha = if (isLive && !isLoading && !hasError) dotAlpha else 1f))
            )
            Text(
                if (isLive) "LIVE" else "PAUSE",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = labelColor,
                letterSpacing = 0.8.sp
            )
            if (isLoading) {
                androidx.compose.material3.CircularProgressIndicator(
                    modifier = Modifier.size(12.dp),
                    strokeWidth = 1.5.dp,
                    color = dotColor
                )
            } else if (lastUpdateMs != null && isLive) {
                val secs = ((15_000L - (nowMs - lastUpdateMs)).coerceAtLeast(0) / 1000L).toInt()
                Text(
                    "${secs}s",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
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
                modifier = Modifier.size(44.dp).clip(CircleShape).background(StatusSuccess.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) { Icon(Icons.Filled.NotificationsActive, null, tint = StatusSuccess, modifier = Modifier.size(20.dp)) }
            Column(modifier = Modifier.weight(1f)) {
                Text("Temps réel", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Text("Positions TCL en direct", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        HorizontalDivider()
        Row(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("15s", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = StatusSuccess)
                Text("intervalle", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                Text(txt, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                Text("dernière maj", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        HorizontalDivider()
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.CheckCircle, null, tint = StatusSuccess, modifier = Modifier.size(16.dp))
            Text("Inutile de rafraîchir manuellement", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun FilterSheet(
    selectedTypes: Set<VehicleType>,
    onToggleType: (VehicleType) -> Unit,
    selectedLines: Set<String>,
    onToggleLine: (String) -> Unit,
    availableLines: List<String>,
    favorites: Set<String>,
    onToggleFavorite: (String) -> Unit,
    showBusTraces: Boolean,
    onToggleBusTraces: () -> Unit,
    showTramTraces: Boolean,
    onToggleTramTraces: () -> Unit,
    showMetroTraces: Boolean,
    onToggleMetroTraces: () -> Unit,
    hasActiveFilters: Boolean,
    onClearFilters: () -> Unit,
    vehicles: List<Vehicle>
) {
    var searchText by remember { mutableStateOf("") }
    var showAllLines by remember { mutableStateOf(false) }
    val countByType = remember(vehicles) { vehicles.groupingBy { it.vehicleType }.eachCount() }
    val filteredLines = if (searchText.isBlank()) availableLines
                        else availableLines.filter { it.contains(searchText, ignoreCase = true) }
    val favoriteLines = filteredLines.filter { it in favorites }
    val otherLines    = filteredLines.filter { it !in favorites }

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 20.dp, top = 16.dp, end = 20.dp, bottom = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Filtres", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            if (hasActiveFilters) {
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { onClearFilters() }
                            .padding(horizontal = 20.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(Icons.Filled.Refresh, null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                        Text("Réinitialiser les filtres", color = MaterialTheme.colorScheme.error, fontSize = 15.sp)
                    }
                    HorizontalDivider()
                }
            }
            item {
                Text(
                    "TRACÉS DES LIGNES",
                    style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 8.dp)
                )
                Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.surfaceVariant, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
                    Column {
                        TraceToggleRow(label = "Bus", checked = showBusTraces, onToggle = onToggleBusTraces)
                        HorizontalDivider(modifier = Modifier.padding(start = 14.dp))
                        TraceToggleRow(label = "Tram", checked = showTramTraces, onToggle = onToggleTramTraces)
                        HorizontalDivider(modifier = Modifier.padding(start = 14.dp))
                        TraceToggleRow(label = "Métro / Funiculaire", checked = showMetroTraces, onToggle = onToggleMetroTraces)
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
            item {
                Text(
                    "TYPE DE VÉHICULE",
                    style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 4.dp)
                )
            }
            items(VehicleType.entries.filter { it != VehicleType.METRO && it != VehicleType.FUNICULAR }.sortedBy { it.sortOrder }) { type ->
                val count = countByType[type] ?: 0
                Row(
                    modifier = Modifier.fillMaxWidth().clickable { onToggleType(type) }
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier.size(28.dp)
                            .background(colorFromHex(type.clusterColorHex).copy(alpha = 0.18f), RoundedCornerShape(7.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            when (type) {
                                VehicleType.TRAM, VehicleType.FUNICULAR -> Icons.Filled.Tram
                                else -> Icons.Filled.DirectionsBus
                            },
                            null, tint = colorFromHex(type.clusterColorHex), modifier = Modifier.size(15.dp)
                        )
                    }
                    Text(type.displayName, modifier = Modifier.weight(1f), fontSize = 15.sp)
                    Text("$count", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
                    if (type in selectedTypes) {
                        Icon(Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                    }
                }
                HorizontalDivider(modifier = Modifier.padding(start = 60.dp))
            }
            if (availableLines.isNotEmpty()) {
                item {
                    OutlinedTextField(
                        value = searchText,
                        onValueChange = { searchText = it; showAllLines = false },
                        placeholder = { Text("Rechercher une ligne...", fontSize = 13.sp) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)
                    )
                }
                if (favoriteLines.isNotEmpty()) {
                    item {
                        Row(
                            modifier = Modifier.padding(start = 20.dp, top = 8.dp, bottom = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(Icons.Filled.Star, null, tint = Color(0xFFFFCC00), modifier = Modifier.size(13.dp))
                            Text("FAVORIS", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    items(favoriteLines, key = { "fav_$it" }) { line ->
                        LineFilterRow(line, line in selectedLines, true, { onToggleLine(line) }, { onToggleFavorite(line) })
                        HorizontalDivider(modifier = Modifier.padding(start = 60.dp))
                    }
                }
                if (otherLines.isNotEmpty()) {
                    item {
                        Text(
                            "TOUTES LES LIGNES",
                            style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(start = 20.dp, top = 8.dp, bottom = 4.dp)
                        )
                    }
                    val shown = if (!showAllLines && otherLines.size > 10) otherLines.take(10) else otherLines
                    items(shown, key = { "other_$it" }) { line ->
                        LineFilterRow(line, line in selectedLines, false, { onToggleLine(line) }, { onToggleFavorite(line) })
                        HorizontalDivider(modifier = Modifier.padding(start = 60.dp))
                    }
                    if (!showAllLines && otherLines.size > 10) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth().clickable { showAllLines = true }
                                    .padding(horizontal = 20.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.Center
                            ) {
                                Text(
                                    "Afficher toutes les lignes (${otherLines.size})",
                                    color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TraceToggleRow(label: String, checked: Boolean, onToggle: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onToggle() }
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = { onToggle() })
    }
}

@Composable
private fun LineFilterRow(
    line: String,
    isSelected: Boolean,
    isFavorite: Boolean,
    onToggle: () -> Unit,
    onToggleFavorite: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onToggle() }
            .padding(horizontal = 20.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier.size(30.dp)
                .background(colorFromHex(LineColors.backgroundHex(line)), MaterialTheme.shapes.small),
            contentAlignment = Alignment.Center
        ) {
            Text(
                line,
                color = colorFromHex(LineColors.textHex(line)),
                fontSize = when { line.length <= 2 -> 11.sp; line.length == 3 -> 9.sp; else -> 7.sp },
                fontWeight = FontWeight.Black
            )
        }
        Text(line, modifier = Modifier.weight(1f), fontSize = 15.sp)
        IconButton(onClick = onToggleFavorite, modifier = Modifier.size(28.dp)) {
            Icon(
                if (isFavorite) Icons.Filled.Star else Icons.Outlined.Star,
                null,
                tint = if (isFavorite) Color(0xFFFFCC00) else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
        }
        if (isSelected) {
            Icon(Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
        }
    }
}

private fun enableLocationComponent(context: android.content.Context, map: MapLibreMap, style: Style) {
    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
        context, Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    if (!granted) return
    @Suppress("MissingPermission")
    map.locationComponent.run {
        activateLocationComponent(
            LocationComponentActivationOptions.builder(context, style)
                .useDefaultLocationEngine(true)
                .build()
        )
        isLocationComponentEnabled = true
        renderMode = RenderMode.COMPASS
        cameraMode  = CameraMode.NONE
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

// ── Vehicle feature helpers ─────────────────────────────────────────────
// Extraits pour éviter la duplication entre le LaunchedEffect(vehicles)
// et la boucle d'interpolation 100 ms.

private fun vehicleIconKey(line: String)  = "v_${line.replace(ICON_KEY_REGEX, "_")}"
private fun vehicleDotKey(line: String)   = "vd_${line.replace(ICON_KEY_REGEX, "_")}"
private fun vehicleArrowKey(line: String) = "va_${line.replace(ICON_KEY_REGEX, "_")}"

private const val EMPTY_FEATURE_COLLECTION = "{\"type\":\"FeatureCollection\",\"features\":[]}"

/**
 * Construit un GeoJSON FeatureCollection pour des tracés [BusLine] sans allouer d'objets Point.
 * Évite l'OOM sur les grands datasets (1700+ segments bus).
 */
private fun buildLinesGeoJson(
    lines: List<BusLine>,
    filters: Set<String>,
    colorFn: (String) -> String
): String = buildString {
    append("{\"type\":\"FeatureCollection\",\"features\":[")
    var first = true
    for (line in lines) {
        if (filters.isNotEmpty() && line.name !in filters) continue
        val coords = line.coordinates
        if (coords.size < 2) continue
        if (!first) append(',')
        first = false
        val color = colorFn(line.name)
        append("{\"type\":\"Feature\",\"geometry\":{\"type\":\"LineString\",\"coordinates\":[")
        var firstCoord = true
        for (c in coords) {
            if (c.size < 2) continue
            if (!firstCoord) append(',')
            firstCoord = false
            append('[').append(c[0]).append(',').append(c[1]).append(']')
        }
        append("]},\"properties\":{\"color\":\"$color\"}}")
    }
    append("]}")    
}

/** Construit un GeoJSON FeatureCollection pour des tracés [TransitLine] sans allouer d'objets Point. */
private fun buildTransitLinesGeoJson(
    lines: List<TransitLine>,
    filters: Set<String>
): String = buildString {
    append("{\"type\":\"FeatureCollection\",\"features\":[")
    var first = true
    for (line in lines) {
        if (filters.isNotEmpty() && line.name !in filters) continue
        val coords = line.coordinates
        if (coords.size < 2) continue
        if (!first) append(',')
        first = false
        val color = toMapColor(line.strokeColorHex)
        append("{\"type\":\"Feature\",\"geometry\":{\"type\":\"LineString\",\"coordinates\":[")
        var firstCoord = true
        for (c in coords) {
            if (c.size < 2) continue
            if (!firstCoord) append(',')
            firstCoord = false
            append('[').append(c[0]).append(',').append(c[1]).append(']')
        }
        append("]},\"properties\":{\"color\":\"$color\"}}")
    }
    append("]}")    
}

/** Échappe les caractères JSON spéciaux dans une string. */
private fun String.jsonEscape(): String =
    if (none { it == '"' || it == '\\' || it < ' ' }) this
    else replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

/** Fragment JSON des propriétés statiques d'un véhicule (jamais modifié entre 2 polls 15s). */
private fun buildVehicleStaticProps(v: Vehicle): String = buildString {
    append("\"id\":\"");           append(v.id.jsonEscape());           append('"')
    append(",\"line\":\"");        append(v.lineName.jsonEscape());      append('"')
    append(",\"destination\":\""); append(v.destination.jsonEscape());   append('"')
    append(",\"icon\":\"");        append(vehicleIconKey(v.lineName));   append('"')
    append(",\"dot_icon\":\"");    append(vehicleDotKey(v.lineName));    append('"')
}

/**
 * Construit le GeoJSON FeatureCollection des véhicules via un StringBuilder réutilisé [sb].
 * Zéro allocation Gson dans le hot path 100 ms — seules lat/lng/bearing changent par tick.
 */
private fun buildVehicleGeoJson(
    vehicles: List<Vehicle>,
    propsCache: HashMap<String, String>,
    arrowCache: HashMap<String, String>,
    vm: LiveVehiclesViewModel,
    nowSec: Double,
    sb: StringBuilder
): String {
    sb.setLength(0)
    sb.append("{\"type\":\"FeatureCollection\",\"features\":[")
    var first = true
    for (v in vehicles) {
        if (!first) sb.append(',')
        first = false
        val animated = vm.animatedVehicleFor(v.id)
        val coord   = animated?.currentInterpolatedCoordinate(nowSec) ?: v.coordinate
        val bearing = animated?.currentInterpolatedBearing(nowSec)    ?: v.bearing
        sb.append("{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[")
        sb.append(coord.longitude)
        sb.append(',')
        sb.append(coord.latitude)
        sb.append("]},\"properties\":{")
        sb.append(propsCache[v.id] ?: buildVehicleStaticProps(v))
        sb.append(",\"arrow_icon\":\"")
        sb.append(if (bearing != 0.0) (arrowCache[v.id] ?: "no_arrow") else "no_arrow")
        sb.append("\",\"bearing\":")
        sb.append(bearing.toFloat())
        sb.append("}")
        sb.append("}")
    }
    sb.append("]}")    
    return sb.toString()
}

private fun buildVehicleFeature(v: Vehicle, animated: AnimatedVehicle?, nowSec: Double): Feature {
    val coord   = animated?.currentInterpolatedCoordinate(nowSec) ?: v.coordinate
    val bearing = animated?.currentInterpolatedBearing(nowSec) ?: v.bearing
    val props   = JsonObject().apply {
        addProperty("id",          v.id)
        addProperty("line",        v.lineName)
        addProperty("destination", v.destination)
        addProperty("icon",        vehicleIconKey(v.lineName))
        addProperty("dot_icon",    vehicleDotKey(v.lineName))
        addProperty("arrow_icon",  if (bearing != 0.0) vehicleArrowKey(v.lineName) else "no_arrow")
        addProperty("bearing",     bearing.toFloat())
    }
    return Feature.fromGeometry(Point.fromLngLat(coord.longitude, coord.latitude), props)
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
    // Bitmap 14×27dp : flèche triangulaire dans les 10dp supérieurs, 17dp transparents en bas.
    // iconAnchor("bottom") place le bas du bitmap au centre du véhicule.
    // iconRotate(bearing) orbit la flèche autour de ce point → pointe toujours vers l'extérieur.
    // Géométrie : cercle radius effectif=19dp (40dp bitmap − 1dp stroke inset).
    // Base de la flèche à 17dp du centre → légèrement en chevauchement → aucun gap visible.
    val w      = (14 * density).toInt().coerceAtLeast(1)
    val h      = (27 * density).toInt().coerceAtLeast(1)
    val hArrow = (10 * density).toInt().coerceAtLeast(1)
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val path = android.graphics.Path()
    path.moveTo(w / 2f, 0f)
    path.lineTo(w.toFloat(), hArrow.toFloat())
    path.lineTo(0f, hArrow.toFloat())
    path.close()
    Canvas(bmp).drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg; style = Paint.Style.FILL })
    return bmp
}

/**
 * Point dezoom — disque plat 12dp, couleur de ligne, sans texte ni bordure.
 * Miroir exact du mode simplifié iOS (latitudeDelta > 0.05 → 12pt dot).
 */
private fun vehicleDotBitmap(line: String): Bitmap {
    val density = android.content.res.Resources.getSystem().displayMetrics.density
    val bg = parseAndroidColor(LineColors.backgroundHex(line))
    val size = (12 * density).toInt().coerceAtLeast(1)
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val cx = size / 2f
    Canvas(bmp).drawCircle(cx, cx, cx, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = bg; style = Paint.Style.FILL
    })
    return bmp
}

/** Données de rendu précalculées pour un arrêt — partagées entre les deux étapes du LaunchedEffect. */
private data class StopEntry(
    val id: String, val lon: Double, val lat: Double,
    val fillHex: String, val circleR: Float, val strokeW: Float,
    val iconKey: String, val visibleLines: List<String>,
    val tier: StopTier, val primaryLine: String?
)

/**
 * Hiérarchie visuelle des arrêts — miroir exact de l'enum Swift `StopTier`.
 *   compactR  = rayon du cercle intérieur coloré en mode compact (dp)
 *   compactSW = épaisseur de l'anneau blanc en mode compact (dp)
 *   badgeDp   = diamètre total du dot en mode badges (dp)
 *   badgeSW   = épaisseur de l'anneau blanc en mode badges (dp)
 *   fillHex   = couleur de remplissage intérieure (vide pour METRO → couleur de ligne)
 */
private enum class StopTier(
    val compactR:  Float,
    val compactSW: Float,
    val badgeDp:   Int,
    val badgeSW:   Float,
    val fillHex:   String
) {
    METRO   (6.0f, 3.0f, 20, 3.0f, ""),
    TRAMWAY (5.5f, 2.5f, 17, 2.5f, "#663399"),
    BUS_C   (4.7f, 2.2f, 15, 2.2f, "#1A338C"),
    BUS     (3.75f, 2.0f, 13, 2.0f, "#808C9E");

    companion object {
        fun from(lines: List<String>): StopTier = when (TransportMode.classifyStopTier(lines)) {
            TransportMode.METRO   -> METRO
            TransportMode.TRAMWAY -> TRAMWAY
            TransportMode.BUS_C   -> BUS_C
            else                  -> BUS
        }
        fun primaryLine(lines: List<String>): String? = TransportMode.primaryStopLine(lines)
    }
}

/**
 * Disque arrêt tier-aware : anneau blanc extérieur + noyau coloré selon la hiérarchie.
 * Utilisé comme fallback en mode badges (arrêts sans ligne visible).
 */
private fun stopCompactBitmap(tier: StopTier, primaryLine: String?): Bitmap {
    val density   = 3f
    val outerDp   = tier.badgeDp.toFloat()
    val outerPx   = (outerDp * density).toInt().coerceAtLeast(1)
    val strokePx  = tier.badgeSW * density
    val bmp       = Bitmap.createBitmap(outerPx, outerPx, Bitmap.Config.ARGB_8888)
    val canvas    = Canvas(bmp)
    val cx = outerPx / 2f; val cy = outerPx / 2f; val rOuter = outerPx / 2f - density * 0.3f
    // Anneau blanc extérieur
    canvas.drawCircle(cx, cy, rOuter, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; style = Paint.Style.FILL
    })
    // Noyau coloré
    val fillColor = if (tier == StopTier.METRO && primaryLine != null)
        parseAndroidColor(LineColors.backgroundHex(primaryLine))
    else parseAndroidColor(tier.fillHex)
    canvas.drawCircle(cx, cy, rOuter - strokePx, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = fillColor; style = Paint.Style.FILL
    })
    return bmp
}

/**
 * Dot tier-aware + capsules de ligne colorées (mode zoom serré).
 * Équivalent iOS : MergedStopAnnotationView.setBadges()
 *
 * Layout :  ●  (dot centré horizontalement, taille selon tier)
 *           gap 2pt
 *           [C26][T1]…  badges hauteur 11pt
 * Le centre du dot coincide avec le centre vertical du bitmap → ICON_ANCHOR_CENTER.
 */
private fun stopBadgeBitmap(lines: List<String>, tier: StopTier, primaryLine: String?): Bitmap {
    val density    = 3f
    val dotSizePx  = (tier.badgeDp * density).toInt()
    val strokePx   = tier.badgeSW * density
    val badgeH     = (14 * density).toInt()
    val gapPx      = (3  * density).toInt()
    val hPadPx     = (4  * density).toInt()
    val spacingPx  = (2  * density).toInt()
    val textSizePx = 9.5f * density
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
    val rOuter = dotSizePx / 2f - density * 0.3f
    // Anneau blanc extérieur
    canvas.drawCircle(cx, cy, rOuter, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; style = Paint.Style.FILL
    })
    // Noyau coloré
    val dotFill = if (tier == StopTier.METRO && primaryLine != null)
        parseAndroidColor(LineColors.backgroundHex(primaryLine))
    else parseAndroidColor(tier.fillHex)
    canvas.drawCircle(cx, cy, rOuter - strokePx, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = dotFill; style = Paint.Style.FILL
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



