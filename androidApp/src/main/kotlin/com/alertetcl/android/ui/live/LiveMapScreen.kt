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
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Subway
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Report
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.IconButton
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import com.alertetcl.shared.models.PositionFreshness
import com.alertetcl.shared.util.DemoShowcase
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
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.LayoutDirection
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.android.ui.map.MapCircleFab
import com.alertetcl.android.ui.map.enableLocationComponent
import com.alertetcl.android.ui.map.mapStyleBuilder
import com.alertetcl.android.ui.map.recenterOnUser
import com.alertetcl.android.ui.map.rememberManagedMapView
import com.alertetcl.shared.models.BusLine
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.LinePalette
import com.alertetcl.shared.models.MergedStop
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.design.MapStyle
import com.alertetcl.shared.models.StopLineFocus
import com.alertetcl.shared.models.DirectionMatching
import com.alertetcl.shared.models.StopMergingEngine
import com.alertetcl.shared.models.TransitLine
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.models.AnimatedVehicle
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.ApproachingVehicle
import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.StopApproach
import com.alertetcl.shared.models.StopPassages
import com.alertetcl.shared.models.PassageGroup
import com.alertetcl.shared.design.AppColors
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.ui.draw.rotate
import androidx.compose.material.icons.filled.ExpandMore
import com.alertetcl.android.ui.components.LineBadge
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.android.ui.theme.compose
import com.alertetcl.shared.services.BusLineService
import com.alertetcl.shared.services.TransitLineService
import com.alertetcl.shared.services.LineTermini
import com.alertetcl.shared.services.TimetableService
import com.alertetcl.shared.services.TransitStopService
import com.alertetcl.shared.viewmodels.LiveVehiclesViewModel
import com.google.gson.JsonObject
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
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
import com.alertetcl.shared.models.MapFilterTexts
import androidx.compose.foundation.layout.offset


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
private const val VEHICLES_HALO_LAYER = "vehicles-halo-layer"
private const val VEHICLES_LAYER  = "vehicles-layer"
private const val VEHICLES_ARROW_LAYER = "vehicles-arrow-layer"
private const val STOPS_LAYER       = "stops-layer"        // CircleLayer mode compact
private const val STOPS_BADGE_LAYER = "stops-badge-layer"  // SymbolLayer mode badges (zoom serré)

// Précompilé une seule fois — réutilisé dans les LaunchedEffect (parité iOS : aucune allocation par tick)
private val ICON_KEY_REGEX = Regex("[^A-Za-z0-9]")

/**
 * Ordre des couches, du bas vers le haut : tracés, arrêts, stations Vélo'v, véhicules. Chaque couche
 * s'insère sous la première couche supérieure déjà présente, ou tout en haut s'il n'y en a pas encore.
 */
private fun addLayerUnder(style: Style, layer: org.maplibre.android.style.layers.Layer, vararg above: String) {
    val anchor = above.firstOrNull { style.getLayer(it) != null }
    if (anchor != null) style.addLayerBelow(layer, anchor) else style.addLayer(layer)
}

/** Normalise un hex TCL vers #RRGGBB lisible par MapLibre */
private fun toMapColor(hex: String): String {
    val c = hex.trim().removePrefix("#")
    return when (c.length) {
        6 -> "#$c"
        8 -> "#${c.substring(2)}" // drop alpha
        else -> AppColors.routeUnknown
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveMapScreen() {
    val androidVm: LiveMapAndroidViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
    val vm = androidVm.vm
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // Alertes pour le bandeau trafic en haut
    val alertsAndroidVm: AlertsAndroidViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
    val alertsVm = alertsAndroidVm.alertsVm

    // Lifecycle: stop polling on background, restart on resume (parité iOS scenePhase)
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> {
                    vm.startPolling()
                    alertsVm.startPolling()
                }
                Lifecycle.Event.ON_STOP -> {
                    vm.stopPolling()
                    alertsVm.stopPolling()
                }
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            // Quitter l'onglet doit arrêter les deux polls (dispose() géré par les ViewModels Android)
            vm.stopPolling()
            alertsVm.stopPolling()
        }
    }
    val vehicles     by vm.vehicles.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val isLoading    by vm.isLoading.collectAsState()
    val vehiclesError by vm.errorMessage.collectAsState()
    val isLive       by vm.isLive.collectAsState()
    val lastUpdateMs by vm.lastUpdateEpochMs.collectAsState()

    val alerts by alertsVm.alerts.collectAsState()
    val alertsError by alertsVm.errorMessage.collectAsState()

    val store = remember { com.alertetcl.android.data.FavoritesStore(context) }
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())
    val storedSubscriptions by store.lineSubscriptions.collectAsState(initial = emptyMap())
    val subscriptions = if (DemoShowcase.isAlertsCase) DemoShowcase.subscriptions() else storedSubscriptions
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
    // Index des fiches horaires : rafraîchit la palette officielle des couleurs de lignes.
    // ... et retire des filtres enregistrés les lignes qui n'existent plus (renumérotation du réseau).
    LaunchedEffect(Unit) {
        val index = runCatching { TimetableService.shared.fetchIndex() }.getOrNull() ?: return@LaunchedEffect
        val saved = store.selectedLiveLines.first()
        val kept = MapFilterTexts.keepKnownLines(saved, index)
        if (kept != saved) store.setSelectedLiveLines(kept)
    }
    // Chaque changement de palette invalide les images de lignes mises en cache dans le style.
    val paletteVersion by LinePalette.version.collectAsState()

    val stopFocus by vm.stopFocus.collectAsState()
    val filteredVehicles by remember {
        derivedStateOf {
            val focus = stopFocus
            // Le filtre d'arrêt prime sur les autres : on veut voir ces bus, quels que soient les réglages.
            if (focus != null) vehicles.filter(focus::matches)
            else vehicles.filter { it.vehicleType in selectedTypes && (selectedLines.isEmpty() || it.lineName in selectedLines) }
        }
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
    val vehicleGlyphs = rememberVehicleGlyphs()
    val tickSb            = remember { StringBuilder(8192) }

    // Selection state
    // Fiche véhicule ouverte : suit la version la plus récente du véhicule et garde la dernière
    // connue s'il quitte la carte (parité iOS), la fiche signale alors la position obsolète.
    val selectedVehicle = remember { mutableStateOf<Vehicle?>(null) }

    val selectedStop      = remember { mutableStateOf<MergedStop?>(null) }

    // Bottom sheet flags
    // Feuille « Trafic et horaires » : les alertes et les fiches horaires derrière un seul bouton.
    var showNetworkSheet by remember { mutableStateOf(false) }
    var networkTab by remember { mutableIntStateOf(0) }
    var showFilterSheet by remember { mutableStateOf(false) }
    var showErrorsSheet by remember { mutableStateOf(false) }
    var timetableStart by remember { mutableStateOf<TimetableStart?>(null) }

    // Mode démo : ouvrir automatiquement la fiche du cas demandé (parité iOS).
    if (DemoShowcase.isActive) {
        LaunchedEffect(Unit) {
            kotlinx.coroutines.delay(6_000)
            when (DemoShowcase.current) {
                "fiche", "fiche-vieille" -> DemoShowcase.vehicleForSheet()?.let { v ->
                    vm.focusOnStop(StopLineFocus.forVehicle(v))
                    selectedVehicle.value = v
                }
                "arret"                  -> selectedStop.value = DemoShowcase.mergedStop()
                "bus-arret"              -> DemoShowcase.stopLineFocus().let { focus ->
                    vm.focusOnStop(focus)
                    fitCameraOnFocus(mapLibreMap, focus, vehicles)
                }
                "horaires", "horaires-ligne", "horaires-arrets" -> { networkTab = 1; showNetworkSheet = true }
                "horaires-arret", "horaires-course" -> {
                    val stop = DemoShowcase.mergedStop()
                    val passage = DemoShowcase.passages(stop.stops[0].id)[0]
                    selectedStop.value = stop
                    timetableStart = TimetableStart.ForStop(passage.ligne, passage.direction, stop.stops.map { it.id }.toSet(), stop.nom)
                }
                "erreur401"              -> showErrorsSheet = true
                "alertes", "alertes-ligne", "alertes-options" -> { networkTab = 0; showNetworkSheet = true }
                else                     -> Unit
            }
        }
    }


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

    val mapView = rememberManagedMapView()

    // Filtres actifs (parité iOS hasActiveFilters — les arrêts sont automatiques, pas un filtre)
    val hasActiveFilters = stopFocus != null ||
        selectedTypes.size != VehicleType.entries.size ||
        showBusTraces || !showTramTraces || !showMetroTraces ||
        selectedLines.isNotEmpty()
    // Filtres enregistrés qui ne laissent plus rien (ligne renumérotée, type sans véhicule) : le dire.
    val filtersHideAll = stopFocus == null && vehicles.isNotEmpty() && filteredVehicles.isEmpty() &&
        (selectedTypes.size != VehicleType.entries.size || selectedLines.isNotEmpty())
    val clearFilters: () -> Unit = {
        vm.clearStopFocus()
        VehicleType.entries.filter { it != VehicleType.METRO && it !in vm.selectedTypes.value }.forEach { vm.toggleType(it) }
        scope.launch {
            store.setSelectedLiveLines(emptySet())
            store.setShowBusTraces(false)
            store.setShowTramTraces(true)
            store.setShowMetroTraces(true)
        }
    }

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
                        map.cameraPosition = if (DemoShowcase.isActive) {
                            // Mode démo : cadrer la scène simulée au zoom des étiquettes d'âge
                            CameraPosition.Builder()
                                .target(LatLng(DemoShowcase.CENTER_LAT, DemoShowcase.CENTER_LON))
                                .zoom(16.2)
                                .build()
                        } else {
                            CameraPosition.Builder()
                                .target(LatLng(45.764043, 4.835659))
                                .zoom(12.5)
                                .build()
                        }
                        map.addOnMapClickListener { latLng ->
                            val screen = map.projection.toScreenLocation(latLng)
                            val pt = PointF(screen.x, screen.y)
                            val vf = map.queryRenderedFeatures(pt, VEHICLES_LAYER)
                            if (vf.isNotEmpty()) {
                                val id = vf[0].getStringProperty("id")
                                // Toucher un véhicule filtre la carte sur sa ligne ; la fiche s'ouvre depuis le bandeau.
                                vehicles.firstOrNull { it.id == id }?.let { vm.focusOnStop(StopLineFocus.forVehicle(it)) }
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
                        map.setStyle(mapStyleBuilder(isSatellite = false, isDark = isDark)) { style ->
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
            val builder = mapStyleBuilder(isSatellite, isDark)
            vehiclesLayerReady.value = false
            mapStyle = null
            map.setStyle(builder) { style ->
                enableLocationComponent(context, map, style)
                mapStyle = style
            }
        }

        // ── Top: Traffic Banner + filtre « bus de cet arrêt » ─────────────
        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
        if (filtersHideAll) FiltersHideAllBanner(onClear = clearFilters)
        stopFocus?.let { focus ->
            val vehicleId = focus.vehicleId
            if (vehicleId != null) {
                val vehicle = vehicles.firstOrNull { it.id == vehicleId }
                VehicleFocusBanner(
                    focus = focus,
                    vehicle = vehicle,
                    onMore = { vehicle?.let { selectedVehicle.value = it } },
                    onClose = { vm.clearStopFocus() }
                )
            } else {
                StopFocusBanner(
                    focus = focus,
                    vehicleCount = vehicles.count(focus::matches),
                    onClear = { vm.clearStopFocus() }
                )
            }
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
            // Messages contextuels : flux vide alors que tout fonctionne, ou données figées.
            var statusNowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
            LaunchedEffect(Unit) {
                while (true) { kotlinx.coroutines.delay(5_000); statusNowMs = System.currentTimeMillis() }
            }
            if (vehiclesError == null && !isLoading && lastUpdateMs != null && vehicles.isEmpty()) {
                StatusCapsule("TCL ne transmet aucune position en ce moment")
            }
            val frozenSec = lastUpdateMs?.let { (statusNowMs - it) / 1000 } ?: 0
            if (isLive && frozenSec > 60) {
                StatusCapsule("Dernières données reçues il y a ${Vehicle.formattedAge(frozenSec)}")
            }
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
                        Icon(Icons.Filled.Warning, null, tint = Tokens.warning, modifier = Modifier.size(14.dp))
                        val n = (if (vehiclesError != null) 1 else 0) + (if (alertsError != null) 1 else 0)
                        Text("$n source${if (n > 1) "s" else ""} en erreur", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
                    }
                }
            }
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
            NetworkFab(subscriptions = subscriptions, alerts = alerts, onClick = { networkTab = 0; showNetworkSheet = true })
            MapCircleFab(icon = Icons.Filled.FilterList, contentDesc = "Filtres", active = hasActiveFilters, onClick = { showFilterSheet = true })
            MapCircleFab(
                icon = Icons.Filled.MyLocation, contentDesc = "Ma position",
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
    LaunchedEffect(mapStyle, showBusTraces, showTramTraces, showMetroTraces, transitLines.value, busLines.value, selectedLines, paletteVersion, stopFocus) {
        val style = mapStyle ?: return@LaunchedEffect
        // Filtre actif : seul le tracé de la ligne filtrée reste visible, quels que soient les réglages.
        val focusedLine = stopFocus?.line

        // Capture immutable snapshots avant de switcher sur Default — évite les lectures de
        // Compose State depuis un thread non-Main (undefined behavior dans le snapshot system).
        val capturedBus     = busLines.value
        val capturedTransit = transitLines.value
        val capturedFilters = focusedLine?.let { setOf(it) } ?: selectedLines
        val capturedBusTraces   = showBusTraces || focusedLine != null
        val capturedTramTraces  = showTramTraces || focusedLine != null
        val capturedMetroTraces = showMetroTraces || focusedLine != null

        // Sérialisation GeoJSON incluse dans le withContext(Default) — aucun JSON sur Main
        fun addOrUpdate(src: String, layer: String, geojson: String, width: Float) {
            if (style.getSource(src) == null) {
                style.addSource(GeoJsonSource(src, geojson))
                // Liseré clair sous le tracé pour le détacher du fond, puis le tracé à la couleur de la ligne.
                val casing = LineLayer("$layer-casing", src).withProperties(
                    PropertyFactory.lineColor("#FFFFFF"),
                    PropertyFactory.lineWidth(width + MapStyle.routeCasingExtraWidth.toFloat()),
                    PropertyFactory.lineOpacity(MapStyle.routeCasingOpacity.toFloat()),
                    PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                    PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)
                )
                val lineLayer = LineLayer(layer, src).withProperties(
                    PropertyFactory.lineColor(Expression.get("color")),
                    PropertyFactory.lineWidth(width),
                    PropertyFactory.lineOpacity(MapStyle.routeOpacity.toFloat()),
                    PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                    PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)
                )
                // Tout en bas : sous les arrêts et les véhicules.
                addLayerUnder(style, casing, STOPS_LAYER, VEHICLES_HALO_LAYER)
                addLayerUnder(style, lineLayer, STOPS_LAYER, VEHICLES_HALO_LAYER)
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

        // Le style a pu être remplacé (satellite / thème) pendant le withContext :
        // toucher un Style invalidé lève IllegalStateException.
        if (!style.isFullyLoaded) return@LaunchedEffect
        glInitMutex.withLock {
            addOrUpdate(BUS_SRC,   BUS_LAYER,   allGeoJsons[0], MapStyle.routeWidth(TransportMode.BUS).toFloat())
            addOrUpdate(BUS_C_SRC, BUS_C_LAYER, allGeoJsons[1], MapStyle.routeWidth(TransportMode.BUS_C).toFloat())
            addOrUpdate(TRAM_SRC,  TRAM_LAYER,  allGeoJsons[2], MapStyle.routeWidth(TransportMode.TRAMWAY).toFloat())
            addOrUpdate(METRO_SRC, METRO_LAYER, allGeoJsons[3], MapStyle.routeWidth(TransportMode.METRO).toFloat())
        }
    }

    // Vehicle markers
    LaunchedEffect(mapStyle, filteredVehicles, paletteVersion) {
        val style = mapStyle ?: return@LaunchedEffect
        val current = filteredVehicles

        // Register circle body + dot + arrow icons (once per unique line)
        if (style.getImage("no_arrow") == null)
            style.addImage("no_arrow", Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))

        // Collecte les lignes manquantes sur Main (style.getImage doit rester sur Main),
        // puis construit les bitmaps Canvas sur Default pour ne pas bloquer le UI thread.
        val toBuild = current.map { it.lineName to it.vehicleType }.distinct()
            .filter { (line, type) -> style.getImage(vehicleIconKey(line, type)) == null }
        if (toBuild.isNotEmpty()) {
            val newBitmaps = withContext(Dispatchers.Default) {
                toBuild.flatMap { (line, type) ->
                    listOf(
                        vehicleIconKey(line, type) to vehicleMarkerBitmap(line, vehicleGlyphs.getValue(type)),
                        vehicleDotKey(line)        to vehicleDotBitmap(line),
                        vehicleArrowKey(line)      to bearingArrowBitmap(line)
                    )
                }
            }
            if (!style.isFullyLoaded) return@LaunchedEffect
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
        val features = current.filter { it.isShownOnMap((nowSec * 1000).toLong()) }
            .map { v -> buildVehicleFeature(v, vm.animatedVehicleFor(v.id), nowSec, vm.stopFocus.value?.vehicleId) }

        if (style.getSource(VEHICLES_SRC) == null) {
            glInitMutex.withLock {
                if (!style.isFullyLoaded) return@LaunchedEffect
                if (style.getSource(VEHICLES_SRC) == null) {
                    style.addSource(GeoJsonSource(VEHICLES_SRC, FeatureCollection.fromFeatures(features)))
                    // Layer 0 : halo à la couleur de la ligne autour du véhicule sélectionné
                    style.addLayer(CircleLayer(VEHICLES_HALO_LAYER, VEHICLES_SRC).withProperties(
                        PropertyFactory.circleRadius(22f),
                        PropertyFactory.circleColor(Expression.get("line_col")),
                        PropertyFactory.circleOpacity(0.22f),
                        PropertyFactory.circleStrokeColor(Expression.get("line_col")),
                        PropertyFactory.circleStrokeWidth(2f),
                        PropertyFactory.circleStrokeOpacity(0.9f)
                    ).withFilter(Expression.eq(Expression.get("sel"), Expression.literal(1))))
                    // Layer 1 : flèche orbitale — sous le corps (z-index inférieur), masquée en dezoom
                    style.addLayer(SymbolLayer(VEHICLES_ARROW_LAYER, VEHICLES_SRC).withProperties(
                        PropertyFactory.iconImage(
                            Expression.step(
                                Expression.zoom(),
                                Expression.literal("no_arrow"),
                                Expression.literal(MapStyle.ZOOM_VEHICLE_BODY), Expression.get("arrow_icon")
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
                                Expression.literal(MapStyle.ZOOM_VEHICLE_BODY), Expression.get("icon")
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
        if (!style.isFullyLoaded) return@LaunchedEffect
        val source = style.getSourceAs<GeoJsonSource>(VEHICLES_SRC) ?: return@LaunchedEffect
        while (true) {
            // Un changement de style invalide `source` : sortir plutôt que crasher
            if (!style.isFullyLoaded) return@LaunchedEffect
            val nowSec  = System.currentTimeMillis() / 1000.0
            val current = vehiclesRef.value
            if (current.isEmpty()) { kotlinx.coroutines.delay(100); continue }
            // Sans transition active : un rebuild par seconde suffit, uniquement
            // pour faire vivre les étiquettes d'âge ("12 s" → "13 s").
            if (!vm.hasAnyActiveTransition(nowSec)) {
                source.setGeoJson(
                    buildVehicleGeoJson(current, vehiclePropsCache, vehicleArrowCache, vm, nowSec, tickSb)
                )
                kotlinx.coroutines.delay(1_000)
                continue
            }
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
    LaunchedEffect(mapStyle, mergedStops, paletteVersion) {
        val style = mapStyle ?: return@LaunchedEffect
        if (mergedStops.isEmpty()) return@LaunchedEffect

        // Étape 1 (Default) : toutes les métadonnées + GeoJSON complet en un seul passage
        val (geojson, allEntries) = withContext(Dispatchers.Default) {
            val entries = mergedStops.map { stop ->
                val lines = stop.allLines.filter { !it.startsWith("JD", ignoreCase = true) }
                val tier  = StopTier.from(lines)
                val pl    = StopTier.primaryLine(lines)
                val fill  = stopFillHex(tier, pl)
                val key   = if (lines.isNotEmpty())
                    "stop${paletteVersion}_${tier.name}_${pl ?: ""}_" + lines.take(4).joinToString("_")
                else "stop${paletteVersion}_dot_${tier.name}_${pl ?: ""}"
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
        if (!style.isFullyLoaded) return@LaunchedEffect
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
            if (!style.isFullyLoaded) return@LaunchedEffect
            built.forEach { (key, bmp) -> style.addImage(key, bmp) }
        }

        // Étape 3 (Main) : source + layers MapLibre
        if (style.getSource(STOPS_SRC) == null) {
            glInitMutex.withLock {
                if (!style.isFullyLoaded) return@LaunchedEffect
                if (style.getSource(STOPS_SRC) == null) {
                    style.addSource(GeoJsonSource(STOPS_SRC, geojson))
                    val circleLayer = CircleLayer(STOPS_LAYER, STOPS_SRC).withProperties(
                            PropertyFactory.circleColor(Expression.get("fill_color")),
                            PropertyFactory.circleStrokeColor("#FFFFFF"),
                            PropertyFactory.circleRadius(Expression.toNumber(Expression.get("circle_r"))),
                            PropertyFactory.circleStrokeWidth(Expression.toNumber(Expression.get("stroke_w")))
                        )
                    circleLayer.setMinZoom(MapStyle.ZOOM_STOPS.toFloat())
                    circleLayer.setMaxZoom(MapStyle.ZOOM_STOP_BADGES.toFloat()) // exclusif : masqué quand badgeLayer prend le relais
                    val badgeLayer = SymbolLayer(STOPS_BADGE_LAYER, STOPS_SRC).withProperties(
                            PropertyFactory.iconImage(Expression.get("icon")),
                            PropertyFactory.iconAllowOverlap(true),
                            PropertyFactory.iconIgnorePlacement(true),
                            PropertyFactory.iconAnchor(Property.ICON_ANCHOR_CENTER)
                        )
                    badgeLayer.setMinZoom(MapStyle.ZOOM_STOP_BADGES.toFloat())
                    // Sous les véhicules, au-dessus des tracés.
                    addLayerUnder(style, circleLayer, VEHICLES_HALO_LAYER)
                    addLayerUnder(style, badgeLayer, VEHICLES_HALO_LAYER)
                }
            }
        } else {
            style.getSourceAs<GeoJsonSource>(STOPS_SRC)?.setGeoJson(geojson)
        }
    }

    // ── Bottom sheets ───────────────────────────────────────────────────

    selectedVehicle.value?.let { selected ->
        // La fiche suit les nouvelles positions tant que le véhicule est sur la carte.
        val v = filteredVehicles.find { it.id == selected.id } ?: selected
        LaunchedEffect(v) { selectedVehicle.value = v }
        ModalBottomSheet(onDismissRequest = { selectedVehicle.value = null }, sheetState = rememberModalBottomSheetState(), contentWindowInsets = { WindowInsets.systemBars }) {
            VehicleDetailSheet(v)
        }
    }
    selectedStop.value?.let { stop ->
        ModalBottomSheet(onDismissRequest = { selectedStop.value = null }, sheetState = rememberModalBottomSheetState(), contentWindowInsets = { WindowInsets.systemBars }) {
            MergedStopDetailSheet(
                stop = stop,
                vehicles = vehicles,
                onFocus = { focus ->
                    selectedStop.value = null
                    vm.focusOnStop(focus)
                    fitCameraOnFocus(mapLibreMap, focus, vehicles)
                },
                onTimetable = { timetableStart = it },
                onLocateVehicle = { vehicle ->
                    selectedStop.value = null
                    vm.focusOnStop(StopLineFocus.forVehicle(vehicle))
                    fitCamera(mapLibreMap, listOf(LatLng(vehicle.latitude, vehicle.longitude), LatLng(stop.latitude, stop.longitude)))
                }
            )
        }
    }
    timetableStart?.let { start ->
        TimetableDialog(start = start, onDismiss = { timetableStart = null })
    }
    if (showNetworkSheet) {
        ModalBottomSheet(onDismissRequest = { showNetworkSheet = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), contentWindowInsets = { WindowInsets.systemBars }) {
            Column(Modifier.fillMaxSize()) {
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
                    SegmentedButton(selected = networkTab == 0, onClick = { networkTab = 0 }, shape = SegmentedButtonDefaults.itemShape(0, 2)) { Text("Trafic") }
                    SegmentedButton(selected = networkTab == 1, onClick = { networkTab = 1 }, shape = SegmentedButtonDefaults.itemShape(1, 2)) { Text("Horaires") }
                }
                Box(Modifier.fillMaxSize()) {
                    if (networkTab == 0) com.alertetcl.android.ui.alerts.AlertsScreen(viewModel = alertsVm)
                    else TimetableFlow(start = TimetableStart.Search, onDismiss = { showNetworkSheet = false })
                }
            }
        }
    }
    if (showFilterSheet) {
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            sheetState = rememberModalBottomSheetState(),
            contentWindowInsets = { WindowInsets.systemBars }
        ) {
            FilterSheet(
                stopFocus = stopFocus,
                onClearStopFocus = { vm.clearStopFocus() },
                isSatellite = isSatellite,
                onToggleSatellite = { isSatellite = !isSatellite },
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
                onClearFilters = clearFilters,
                vehicles = vehicles
            )
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
    // Couleur officielle de la ligne du véhicule : toute la fiche s'y accorde.
    val accentColor = colorFromHex(LineColors.backgroundHex(v.lineName))
    val accentText = colorFromHex(LineColors.textHex(v.lineName))
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
                                tint = accentText,
                                modifier = Modifier.size(20.dp)
                            )
                            Text(
                                text = v.lineName,
                                color = accentText,
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
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                        v.isDelayed -> Tokens.warning
                        v.isEarly   -> MaterialTheme.colorScheme.primary
                        else        -> Tokens.success
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

                    // Fraîcheur de la position : âge de la dernière transmission TCL,
                    // mis à jour chaque seconde tant que la fiche est ouverte.
                    if (v.recordedAtEpoch != null) {
                        var nowMs by remember { mutableStateOf(System.currentTimeMillis()) }
                        LaunchedEffect(Unit) {
                            while (true) {
                                nowMs = System.currentTimeMillis()
                                kotlinx.coroutines.delay(1_000)
                            }
                        }
                        val age = v.positionAgeSeconds(nowMs) ?: 0L
                        val freshness = v.positionFreshness(nowMs)
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(7.dp)
                                    .background(
                                        freshness.color.compose(),
                                        androidx.compose.foundation.shape.CircleShape
                                    )
                            )
                            Text(
                                "Position transmise par TCL il y a ${Vehicle.formattedAge(age)}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        if (freshness == PositionFreshness.STALE) {
                            Text(
                                "TCL n'a rien envoyé de plus récent pour ce véhicule, sa position réelle a probablement changé.",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.outline
                            )
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
                                            color = MaterialTheme.colorScheme.primary,
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
private fun MergedStopDetailSheet(
    stop: MergedStop,
    /** Positions des véhicules, pour « où est mon bus ». */
    vehicles: List<Vehicle>,
    /** Montre sur la carte les véhicules d'une ligne dans un sens (le parent applique le filtre et referme la fiche). */
    onFocus: (StopLineFocus) -> Unit,
    /** Ouvre la fiche horaire théorique d'une ligne à cet arrêt. */
    onTimetable: (TimetableStart.ForStop) -> Unit,
    /** Cadre la carte sur un véhicule en approche et l'arrêt. */
    onLocateVehicle: (Vehicle) -> Unit
) {
    val context = LocalContext.current
    // Terminus par ligne et sens, pour déduire le sens d'une destination affichée.
    val termini by produceState(initialValue = emptyMap<String, String>()) { value = runCatching { LineTermini.all() }.getOrDefault(emptyMap()) }
    // Ordre des arrêts de chaque sens affiché, chargé une fois par fiche ouverte (« où est mon bus ») ; clé `PassageGroup.key`.
    val timetables = remember(stop.id) { mutableStateMapOf<String, LineTimetable>() }
    val timetableLookups = remember(stop.id) { mutableSetOf<String>() }
    // Sens dépliés dans la liste des prochains passages.
    val expandedGroups = remember(stop.id) { mutableStateListOf<String>() }
    var passagesKey by remember(stop.id) { mutableStateOf(0) }
    var passagesHadError by remember(stop.id) { mutableStateOf(false) }
    val passages = produceState<List<Passage>?>(initialValue = null, stop.id, passagesKey) {
        passagesHadError = false
        var anyError = false
        // Un quai à la fois dès qu'il répond : l'attente perçue est celle du plus rapide, pas du plus lent.
        val loaded = mutableMapOf<Int, List<Passage>>()
        coroutineScope {
            stop.stops.forEach { member ->
                launch {
                    val list = try {
                        TransitStopService.shared.fetchPassagesForStop(member.id)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        anyError = true
                        emptyList()
                    }
                    loaded[member.id] = list
                    val merged = loaded.values.flatten().sortedBy { it.heurepassage }
                    if (merged.isNotEmpty() || loaded.size == stop.stops.size) value = merged
                }
            }
        }
        passagesHadError = anyError
        if (value == null) value = emptyList()
    }
    // Rafraîchit les passages toutes les 30 s tant que la fiche est ouverte.
    LaunchedEffect(stop.id) {
        while (true) {
            kotlinx.coroutines.delay(30_000)
            passagesKey++
        }
    }
    // Un groupe par ligne et par sens réel (module partagé) : le sens vient du quai du passage, le
    // terminus du sens ; une rame qui s'arrête avant reste dans son sens.
    val groupedPassages = remember(passages.value, termini) {
        val list = passages.value ?: return@remember emptyList<PassageGroup>()
        StopPassages.group(list, stop.stops.associate { it.id to it.desserte }, termini)
    }
    LaunchedEffect(groupedPassages, termini) {
        for (group in groupedPassages) {
            if (!timetableLookups.add(group.key)) continue
            launch {
                runCatching {
                    TimetableService.shared.findForStop(group.line, group.terminus, stop.stops.map { it.id }.toSet(), stop.nom, termini)
                }.getOrNull()?.let { timetables[group.key] = it }
            }
        }
    }
    val timetableSnapshot: Map<String, LineTimetable> = timetables.toMap()
    val approaches = remember(vehicles, timetableSnapshot) {
        val nowMs = System.currentTimeMillis()
        timetableSnapshot.mapValues { (_, timetable) ->
            StopApproach.approaching(vehicles, timetable, stop.stops.map { it.id }, stop.nom, nowMs)
        }.filterValues { it.isNotEmpty() }
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
                            LineBadge(line, size = 28.dp, fontSize = 12.sp)
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

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("Prochains passages", fontWeight = FontWeight.Bold, fontSize = 22.sp)
            IconButton(onClick = { passagesKey++ }, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Filled.Refresh, "Rafraîchir les passages",
                    tint = Tokens.accent, modifier = Modifier.size(18.dp))
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
                // Une ligne par sens, dans une carte sobre ; un toucher déplie les détails du sens.
                Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                        groupedPassages.forEachIndexed { index, group ->
                            if (index > 0) HorizontalDivider()
                            PassageGroupRow(
                                group = group,
                                expanded = group.key in expandedGroups,
                                approaching = approaches[group.key].orEmpty(),
                                approachKnown = timetables[group.key] != null,
                                onToggle = { if (group.key in expandedGroups) expandedGroups.remove(group.key) else expandedGroups.add(group.key) },
                                onLocate = { approach -> vehicles.firstOrNull { it.id == approach.vehicle.id }?.let(onLocateVehicle) },
                                onShowOnMap = {
                                    onFocus(
                                        StopLineFocus(
                                            line = group.line,
                                            direction = group.directionCode,
                                            destination = group.terminus,
                                            stopName = stop.nom,
                                            latitude = stop.latitude,
                                            longitude = stop.longitude
                                        )
                                    )
                                },
                                onShowTimetable = {
                                    onTimetable(TimetableStart.ForStop(group.line, group.terminus, stop.stops.map { it.id }.toSet(), stop.nom))
                                }
                            )
                        }
                    }
                }
                Text(
                    "Un point vert marque un passage suivi en direct ; les autres suivent l'horaire prévu.",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 10.dp, start = 4.dp, end = 4.dp)
                )
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

/**
 * Un sens d'une ligne à cet arrêt : le terminus, les trois prochains passages, et au toucher les
 * détails (où est mon bus, voir sur la carte, tous les horaires). Parité iOS `PassageGroupRow`.
 */
@Composable
private fun PassageGroupRow(
    group: PassageGroup,
    expanded: Boolean,
    approaching: List<ApproachingVehicle>,
    approachKnown: Boolean,
    onToggle: () -> Unit,
    onLocate: (ApproachingVehicle) -> Unit,
    onShowOnMap: () -> Unit,
    onShowTimetable: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().clickable { onToggle() },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            LineBadge(group.line, size = 32.dp, fontSize = 13.sp)
            Text(group.terminus, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Icon(
                Icons.Filled.ExpandMore, null, tint = MaterialTheme.colorScheme.outline,
                modifier = Modifier.size(20.dp).rotate(if (expanded) 180f else 0f)
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.Top) {
            group.passages.take(3).forEachIndexed { index, p -> PassageCell(p, first = index == 0, shortDestination = group.shortDestination(p)) }
        }
        if (expanded) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(top = 2.dp)) {
                if (approaching.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Où est mon bus", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                        approaching.forEach { approach ->
                            ApproachRow(approach = approach, line = group.line, onLocate = { onLocate(approach) })
                        }
                    }
                } else if (approachKnown && TransportMode.detectFromLine(group.line).showOnMapLabel != null) {
                    Text(StopApproach.NONE_APPROACHING, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    val showOnMapLabel = TransportMode.detectFromLine(group.line).showOnMapLabel
                    if (showOnMapLabel != null) CardActionButton(showOnMapLabel, Icons.Filled.Map, Modifier.weight(1f), onShowOnMap)
                    CardActionButton("Tous les horaires", Icons.Filled.CalendarMonth, Modifier.weight(1f), onShowTimetable)
                }
            }
        }
    }
}

/** Délai en chiffres, point vert quand le véhicule est suivi en direct, destination courte s'il ne va pas au terminus. */
@Composable
private fun PassageCell(p: Passage, first: Boolean, shortDestination: String?) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            if (p.isRealTime) Box(Modifier.size(6.dp).background(Tokens.success, CircleShape))
            Text(
                p.delaipassage.ifBlank { "--" },
                fontSize = if (first) 17.sp else 15.sp,
                fontWeight = if (first) FontWeight.SemiBold else FontWeight.Normal,
                color = if (first) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (shortDestination != null) {
            Text("jusqu'à $shortDestination", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
        }
    }
}

/**
 * Un véhicule en approche : deux grands chiffres (arrêts restants, heure estimée) et une ligne sur l'âge
 * de la position. Toucher la carte montre le bus sur la carte (parité iOS).
 */
@Composable
private fun ApproachRow(approach: ApproachingVehicle, line: String, onLocate: (() -> Unit)?) {
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { kotlinx.coroutines.delay(1000); nowMs = System.currentTimeMillis() } }
    val lineColor = colorFromHex(LineColors.backgroundHex(line))
    Surface(shape = RoundedCornerShape(14.dp), color = lineColor.copy(alpha = 0.08f), modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth().let { m -> if (onLocate != null) m.clickable(onClick = onLocate) else m },
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                ApproachStat(approach.stopsValue, approach.stopsCaption, MaterialTheme.colorScheme.onSurface)
                ApproachStat(approach.estimatedTime()?.let { "≈ $it" } ?: "—", approach.arrivalText(nowMs) ?: "heure inconnue", MaterialTheme.colorScheme.primary)
                Spacer(Modifier.weight(1f))
                Icon(Icons.Filled.ChevronRight, null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.padding(top = 8.dp))
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.size(7.dp).background(approach.vehicle.positionFreshness(nowMs).color.compose(), CircleShape))
                Text(approach.freshnessLine(nowMs), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** Un grand chiffre et sa légende (fiche d'arrêt). */
@Composable
private fun ApproachStat(value: String, caption: String, color: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, fontSize = 26.sp, fontWeight = FontWeight.Bold, color = color, maxLines = 1)
        Text(caption, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
    }
}

@Composable
/** Action de la carte : un lien sobre à l'accent, pictogramme puis texte, sans fond. */
private fun CardActionButton(label: String, icon: ImageVector, modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier = modifier.heightIn(min = 36.dp).clickable { onClick() },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Icon(icon, null, tint = Tokens.accent, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Tokens.accent, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/**
 * Remplace le bandeau trafic quand un véhicule a été touché : trois chiffres, le délai depuis la
 * dernière position en premier, « Voir plus » pour la fiche, une croix pour retirer le filtre
 * (parité iOS VehicleFocusCard).
 */
@Composable
private fun VehicleFocusBanner(focus: StopLineFocus, vehicle: Vehicle?, onMore: () -> Unit, onClose: () -> Unit) {
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { kotlinx.coroutines.delay(1000); nowMs = System.currentTimeMillis() } }
    val lineColor = colorFromHex(LineColors.backgroundHex(focus.line))
    val lineText = colorFromHex(LineColors.textHex(focus.line))
    Surface(shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surfaceContainerHigh, shadowElevation = 4.dp,
        border = androidx.compose.foundation.BorderStroke(1.dp, lineColor.copy(alpha = 0.35f)),
        modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LineBadge(focus.line, size = 30.dp, fontSize = 11.sp)
                Column(modifier = Modifier.weight(1f)) {
                    Text(focus.bannerTitle, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    Text("→ ${vehicle?.destination ?: focus.destination}", style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                if (vehicle != null) {
                    Button(
                        onClick = onMore,
                        colors = ButtonDefaults.buttonColors(containerColor = lineColor, contentColor = lineText),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 4.dp)
                    ) { Text("Voir plus", fontSize = 12.sp, fontWeight = FontWeight.SemiBold) }
                }
                FilledTonalIconButton(onClick = onClose, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Filled.Close, contentDescription = "Fermer", modifier = Modifier.size(16.dp))
                }
            }
            if (vehicle != null) {
                val age = vehicle.positionAgeSeconds(nowMs)
                val delayColor = when {
                    vehicle.isDelayed -> Tokens.warning
                    vehicle.isEarly -> MaterialTheme.colorScheme.primary
                    else -> Tokens.success
                }
                Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FocusStat(age?.let { Vehicle.formattedAge(it) } ?: "—", "dernière position", vehicle.positionFreshness(nowMs).color.compose(), emphasized = true)
                    FocusStat(vehicle.delayFormatted, if (vehicle.isDelayed) "retard" else if (vehicle.isEarly) "avance" else "horaire", delayColor, emphasized = false)
                    vehicle.nextStop?.stopName?.let { name ->
                        val at = vehicle.nextStop?.aimedArrivalTimeEpoch ?: vehicle.nextStop?.aimedDepartureTimeEpoch
                        val time = at?.let { java.time.Instant.ofEpochSecond(it).atZone(java.time.ZoneId.systemDefault()).toLocalTime().let { t -> "%02d:%02d".format(t.hour, t.minute) } } ?: "—"
                        FocusStat(time, name, MaterialTheme.colorScheme.onSurface, emphasized = false)
                    }
                }
            } else {
                Text("Véhicule plus suivi pour l'instant", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** Un chiffre et sa légende ; le premier, mis en avant, est plus grand. */
@Composable
private fun androidx.compose.foundation.layout.RowScope.FocusStat(value: String, caption: String, color: Color, emphasized: Boolean) {
    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, fontSize = if (emphasized) 22.sp else 15.sp, fontWeight = FontWeight.Bold, color = color, maxLines = 1,
            fontFamily = FontFamily.Monospace)
        Text(caption, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Les filtres masquent tous les véhicules : une phrase et « Tout afficher » (parité iOS FiltersHideAllBanner). */
@Composable
private fun FiltersHideAllBanner(onClear: () -> Unit) {
    Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surfaceContainerHigh, shadowElevation = 4.dp,
        border = androidx.compose.foundation.BorderStroke(1.dp, Tokens.warning.copy(alpha = 0.35f)), modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(start = 12.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Icon(Icons.Filled.FilterList, null, tint = Tokens.warning, modifier = Modifier.size(22.dp))
            Text(MapFilterTexts.HIDING_EVERYTHING, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 2,
                modifier = Modifier.weight(1f))
            TextButton(onClick = onClear) { Text("Tout afficher", fontSize = 12.sp) }
        }
    }
}

/** Bandeau « bus de cet arrêt » sous le bandeau trafic (parité iOS StopFocusBanner). */
@Composable
private fun StopFocusBanner(focus: StopLineFocus, vehicleCount: Int, onClear: () -> Unit) {
    Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surfaceContainerHigh, shadowElevation = 4.dp, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(start = 12.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            LineBadge(focus.line, size = 28.dp, fontSize = 11.sp)
            Column(modifier = Modifier.weight(1f)) {
                Text(focus.bannerTitle, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(focus.bannerSubtitle(vehicleCount), style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            TextButton(onClick = onClear) { Text("Tout afficher", fontSize = 12.sp) }
        }
    }
}

/** Cadre l'arrêt et les véhicules concernés par le filtre d'arrêt. */
private fun fitCameraOnFocus(map: MapLibreMap?, focus: StopLineFocus, vehicles: List<Vehicle>) {
    fitCamera(map, vehicles.filter(focus::matches).map { LatLng(it.latitude, it.longitude) } + LatLng(focus.latitude, focus.longitude))
}

/** Cadre la carte sur des points, avec un cadre minimal quand ils sont proches. */
private fun fitCamera(map: MapLibreMap?, points: List<LatLng>) {
    val m = map ?: return
    if (points.isEmpty()) return
    val latSpan = points.maxOf { it.latitude } - points.minOf { it.latitude }
    val lonSpan = points.maxOf { it.longitude } - points.minOf { it.longitude }
    // Cadre minimal quand tout est concentré près de l'arrêt (parité iOS : 0,012°).
    if (latSpan < 0.012 && lonSpan < 0.012) {
        val center = LatLng(
            (points.maxOf { it.latitude } + points.minOf { it.latitude }) / 2,
            (points.maxOf { it.longitude } + points.minOf { it.longitude }) / 2
        )
        m.animateCamera(CameraUpdateFactory.newLatLngZoom(center, 14.5))
        return
    }
    val bounds = LatLngBounds.Builder().apply { points.forEach { include(it) } }.build()
    val paddingPx = (56 * android.content.res.Resources.getSystem().displayMetrics.density).toInt()
    m.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, paddingPx))
}

// ── Traffic Banner / Live Indicator / Filter Sheet ──────────────────────


/**
 * Bouton « Trafic et horaires » en bas à droite : une horloge au repos ; plein, avec le nombre de
 * lignes touchées, dès qu'il y a des perturbations sur les lignes suivies.
 */
@Composable
private fun NetworkFab(
    subscriptions: Map<String, com.alertetcl.shared.models.LineSubscription>,
    alerts: List<com.alertetcl.shared.models.TCLAlert>,
    onClick: () -> Unit
) {
    val state = remember(subscriptions, alerts) {
        com.alertetcl.shared.models.TrafficBanner.compute(subscriptions, alerts, System.currentTimeMillis() / 1000L)
    }
    val icon = when (state.tone) {
        com.alertetcl.shared.models.TrafficBanner.Tone.NORMAL -> Icons.Filled.Schedule
        com.alertetcl.shared.models.TrafficBanner.Tone.WARNING -> Icons.Filled.Warning
        com.alertetcl.shared.models.TrafficBanner.Tone.MAJOR -> Icons.Filled.Report
    }
    Box {
        MapCircleFab(icon = icon, contentDesc = "Trafic et horaires", active = state.count > 0, onClick = onClick)
        if (state.count > 0) {
            Surface(shape = RoundedCornerShape(50), color = Tokens.accent, border = androidx.compose.foundation.BorderStroke(1.5.dp, Color.White), modifier = Modifier.align(Alignment.TopEnd).offset(x = 4.dp, y = (-4).dp)) {
                Text("${state.count}", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp))
            }
        }
    }
}

/** Capsule d'information sobre en bas à gauche de la carte. */
@Composable
private fun StatusCapsule(text: String) {
    Surface(
        shape = RoundedCornerShape(50),
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        shadowElevation = 3.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(Icons.Filled.Warning, null, tint = Tokens.warning, modifier = Modifier.size(14.dp))
            Text(text, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun FilterSheet(
    stopFocus: StopLineFocus?,
    onClearStopFocus: () -> Unit,
    isSatellite: Boolean,
    onToggleSatellite: () -> Unit,
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
    val presentTypes = VehicleType.entries.filter { (countByType[it] ?: 0) > 0 }.sortedBy { it.sortOrder }
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
            if (hasActiveFilters) {
                TextButton(onClick = { onClearFilters(); searchText = ""; showAllLines = false }) {
                    Text("Tout réafficher", color = Tokens.accent, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            if (stopFocus != null) {
                item {
                    FilterSectionTitle("Bus d'un arrêt")
                    FilterCard {
                        Row(
                            modifier = Modifier.fillMaxWidth().clickable { onClearStopFocus() }
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            LineBadge(stopFocus.line, size = 30.dp, fontSize = 11.sp)
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Vers ${stopFocus.destination}", fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text("Seuls ces véhicules sont affichés. Touchez pour tout réafficher.",
                                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
            item {
                FilterSectionTitle("Carte")
                FilterCard {
                    TraceToggleRow(icon = Icons.Filled.Public, label = "Vue satellite", checked = isSatellite, onToggle = onToggleSatellite)
                    HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                    TraceToggleRow(icon = Icons.Filled.DirectionsBus, label = "Tracés des bus", checked = showBusTraces, onToggle = onToggleBusTraces)
                    HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                    TraceToggleRow(icon = Icons.Filled.Tram, label = "Tracés des trams", checked = showTramTraces, onToggle = onToggleTramTraces)
                    HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                    TraceToggleRow(icon = Icons.Filled.Subway, label = "Tracés du métro et du funiculaire", checked = showMetroTraces, onToggle = onToggleMetroTraces)
                }
            }
            if (presentTypes.isNotEmpty()) {
                item {
                    FilterSectionTitle("Véhicules affichés")
                    FilterCard {
                        presentTypes.forEachIndexed { index, type ->
                            if (index > 0) HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth().clickable { onToggleType(type) }
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Box(
                                    modifier = Modifier.size(30.dp)
                                        .background(Tokens.vehicleType(type).copy(alpha = 0.18f), RoundedCornerShape(8.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(vehicleTypeIcon(type), null, tint = Tokens.vehicleType(type), modifier = Modifier.size(16.dp))
                                }
                                Text(type.displayName, modifier = Modifier.weight(1f), fontSize = 15.sp)
                                Text("${countByType[type] ?: 0}", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
                                Switch(checked = type in selectedTypes, onCheckedChange = { onToggleType(type) })
                            }
                        }
                    }
                }
            }
            if (availableLines.isNotEmpty()) {
                item {
                    FilterSectionTitle("Lignes")
                    OutlinedTextField(
                        value = searchText,
                        onValueChange = { searchText = it; showAllLines = false },
                        placeholder = { Text("Rechercher une ligne", fontSize = 14.sp) },
                        leadingIcon = { Icon(Icons.Filled.Search, null) },
                        singleLine = true,
                        shape = MaterialTheme.shapes.medium,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp)
                    )
                }
                if (favoriteLines.isNotEmpty()) {
                    item { FilterSectionTitle("Favoris") }
                    item {
                        FilterCard {
                            favoriteLines.forEachIndexed { index, line ->
                                if (index > 0) HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                                LineFilterRow(line, line in selectedLines, true, { onToggleLine(line) }, { onToggleFavorite(line) })
                            }
                        }
                    }
                }
                if (otherLines.isNotEmpty()) {
                    item { FilterSectionTitle("Toutes les lignes") }
                    val shown = if (!showAllLines && otherLines.size > 10) otherLines.take(10) else otherLines
                    item {
                        FilterCard {
                            shown.forEachIndexed { index, line ->
                                if (index > 0) HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                                LineFilterRow(line, line in selectedLines, false, { onToggleLine(line) }, { onToggleFavorite(line) })
                            }
                            if (!showAllLines && otherLines.size > 10) {
                                HorizontalDivider()
                                Row(
                                    modifier = Modifier.fillMaxWidth().clickable { showAllLines = true }
                                        .padding(horizontal = 14.dp, vertical = 12.dp),
                                    horizontalArrangement = Arrangement.Center
                                ) {
                                    Text("Afficher toutes les lignes (${otherLines.size})", color = Tokens.accent, style = MaterialTheme.typography.bodyMedium)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterSectionTitle(text: String) {
    Text(
        text.uppercase(),
        style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 20.dp, top = 18.dp, bottom = 8.dp)
    )
}

@Composable
private fun FilterCard(content: @Composable () -> Unit) {
    Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.surfaceVariant, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
        Column { content() }
    }
}

@Composable
private fun TraceToggleRow(icon: ImageVector, label: String, checked: Boolean, onToggle: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onToggle() }
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier.size(30.dp).background(Tokens.accent.copy(alpha = 0.14f), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = Tokens.accent, modifier = Modifier.size(16.dp))
        }
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
            .padding(horizontal = 14.dp, vertical = 10.dp),
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
                tint = if (isFavorite) Tokens.favorite else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
        }
        if (isSelected) {
            Icon(Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
        }
    }
}


// ── Vehicle feature helpers ─────────────────────────────────────────────
// Extraits pour éviter la duplication entre le LaunchedEffect(vehicles)
// et la boucle d'interpolation 100 ms.

// La version de la palette fait partie des clés : un changement de couleurs régénère les images.
private fun vehicleIconKey(line: String, type: VehicleType) = "v${LinePalette.version.value}_${type.iconKey}_${line.replace(ICON_KEY_REGEX, "_")}"
private fun vehicleDotKey(line: String)   = "vd${LinePalette.version.value}_${line.replace(ICON_KEY_REGEX, "_")}"
private fun vehicleArrowKey(line: String) = "va${LinePalette.version.value}_${line.replace(ICON_KEY_REGEX, "_")}"

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
    append(",\"icon\":\"");        append(vehicleIconKey(v.lineName, v.vehicleType));   append('"')
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
    val nowMs = (nowSec * 1000).toLong()
    var first = true
    for (v in vehicles) {
        // Un véhicule peut franchir le délai d'obsolescence entre deux fetchs : il quitte la carte au tick suivant.
        if (!v.isShownOnMap(nowMs)) continue
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
        appendDynamicProps(sb, v, vm.stopFocus.value?.vehicleId)
        sb.append("}")
        sb.append("}")
    }
    sb.append("]}")    
    return sb.toString()
}

private fun buildVehicleFeature(v: Vehicle, animated: AnimatedVehicle?, nowSec: Double, focusedId: String?): Feature {
    val coord   = animated?.currentInterpolatedCoordinate(nowSec) ?: v.coordinate
    val bearing = animated?.currentInterpolatedBearing(nowSec) ?: v.bearing
    val props   = JsonObject().apply {
        addProperty("id",          v.id)
        addProperty("line",        v.lineName)
        addProperty("destination", v.destination)
        addProperty("icon",        vehicleIconKey(v.lineName, v.vehicleType))
        addProperty("dot_icon",    vehicleDotKey(v.lineName))
        addProperty("arrow_icon",  if (bearing != 0.0) vehicleArrowKey(v.lineName) else "no_arrow")
        addProperty("bearing",     bearing.toFloat())
        addProperty("sel",         if (v.id == focusedId) 1 else 0)
        addProperty("line_col",    LineColors.backgroundHex(v.lineName))
    }
    return Feature.fromGeometry(Point.fromLngLat(coord.longitude, coord.latitude), props)
}

/** Propriétés dynamiques ajoutées au GeoJSON du hot path : sélection et couleur de ligne. */
private fun appendDynamicProps(sb: StringBuilder, v: Vehicle, focusedId: String?) {
    sb.append(",\"sel\":").append(if (v.id == focusedId) 1 else 0)
    sb.append(",\"line_col\":\"").append(LineColors.backgroundHex(v.lineName)).append('"')
}

// ── Bitmap helpers ───────────────────────────────────────────────────────

private fun parseAndroidColor(hex: String): Int {
    val s = hex.removePrefix("#")
    return try { AndroidColor.parseColor(if (s.length == 6 || s.length == 8) "#$s" else "#888888") }
    catch (_: Exception) { AndroidColor.GRAY }
}

/** Diamètre du disque d'un véhicule, en dp (MapLibre divise par la densité). */
private const val VEHICLE_DISC_DP = 40
/** Espace entre le disque et l'étiquette du numéro (la flèche de cap orbite jusqu'à 27 dp du centre). */
private const val VEHICLE_LABEL_GAP_DP = 8
private const val VEHICLE_LABEL_HEIGHT_DP = 14

/**
 * Pictogrammes des types de véhicule (icônes Material, en blanc) rendus une fois en bitmap dans la
 * composition ; les marqueurs, construits hors du fil principal, les teintent ensuite à la couleur
 * de texte de la ligne.
 */
@Composable
private fun rememberVehicleGlyphs(): Map<VehicleType, Bitmap> {
    val density = LocalDensity.current
    val painters = VehicleType.entries.associateWith { rememberVectorPainter(vehicleTypeIcon(it)) }
    return remember(painters, density) {
        painters.mapValues { (_, painter) ->
            val px = with(density) { 20.dp.roundToPx() }.coerceAtLeast(1)
            val image = ImageBitmap(px, px)
            CanvasDrawScope().draw(density, LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(image), Size(px.toFloat(), px.toFloat())) {
                with(painter) { draw(size, colorFilter = ColorFilter.tint(Color.White)) }
            }
            image.asAndroidBitmap()
        }
    }
}

/**
 * Marqueur véhicule : disque à la couleur de la ligne portant le pictogramme de son type, et le
 * numéro de ligne dans une capsule juste en dessous. Le bitmap est symétrique autour du disque pour
 * que son centre reste la position du véhicule. La flèche de cap est sur VEHICLES_ARROW_LAYER.
 */
private fun vehicleMarkerBitmap(line: String, glyph: Bitmap): Bitmap {
    val density = android.content.res.Resources.getSystem().displayMetrics.density
    val bg = parseAndroidColor(LineColors.backgroundHex(line))
    val tx = parseAndroidColor(LineColors.textHex(line))
    val disc = VEHICLE_DISC_DP * density
    val half = disc / 2 + (VEHICLE_LABEL_GAP_DP + VEHICLE_LABEL_HEIGHT_DP) * density
    val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = tx; textSize = 10f * density; textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT_BOLD
    }
    val labelWidth = labelPaint.measureText(line) + 10f * density
    val width = maxOf(disc, labelWidth).toInt().coerceAtLeast(1)
    val height = (half * 2).toInt().coerceAtLeast(1)
    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val cx = width / 2f; val cy = height / 2f; val radius = disc / 2f - density
    canvas.drawCircle(cx, cy, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg; style = Paint.Style.FILL })
    canvas.drawCircle(cx, cy, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.argb(38, 0, 0, 0); style = Paint.Style.STROKE; strokeWidth = density
    })
    // Pictogramme teinté à la couleur de texte de la ligne.
    canvas.drawBitmap(glyph, cx - glyph.width / 2f, cy - glyph.height / 2f, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
        colorFilter = android.graphics.PorterDuffColorFilter(tx, android.graphics.PorterDuff.Mode.SRC_IN)
    })
    // Capsule du numéro de ligne, sous le disque.
    val labelTop = cy + disc / 2 + VEHICLE_LABEL_GAP_DP * density
    val labelRect = RectF(cx - labelWidth / 2, labelTop, cx + labelWidth / 2, labelTop + VEHICLE_LABEL_HEIGHT_DP * density)
    canvas.drawRoundRect(labelRect, labelRect.height() / 2, labelRect.height() / 2, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg; style = Paint.Style.FILL })
    canvas.drawRoundRect(labelRect, labelRect.height() / 2, labelRect.height() / 2, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.argb(38, 0, 0, 0); style = Paint.Style.STROKE; strokeWidth = density
    })
    val baseline = labelRect.centerY() - (labelPaint.descent() + labelPaint.ascent()) / 2
    canvas.drawText(line, cx, baseline, labelPaint)
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
    TRAMWAY (5.5f, 2.5f, 17, 2.5f, ""),
    BUS_C   (4.7f, 2.2f, 15, 2.2f, AppColors.stopMarkerBusC),
    BUS     (3.75f, 2.0f, 13, 2.0f, AppColors.stopMarkerBus);

    companion object {
        /** Métro et tramway prennent la couleur officielle de leur ligne principale. */
        val usesLineColor = setOf(METRO, TRAMWAY)

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
    canvas.drawCircle(cx, cy, rOuter - strokePx, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = parseAndroidColor(stopFillHex(tier, primaryLine)); style = Paint.Style.FILL
    })
    return bmp
}

/** Couleur du noyau d'un arrêt : celle de la ligne principale pour le métro et le tramway, sinon celle du tier. */
private fun stopFillHex(tier: StopTier, primaryLine: String?): String =
    if (tier in StopTier.usesLineColor) LineColors.backgroundHex(primaryLine ?: "") else tier.fillHex

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
    canvas.drawCircle(cx, cy, rOuter - strokePx, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = parseAndroidColor(stopFillHex(tier, primaryLine)); style = Paint.Style.FILL
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



