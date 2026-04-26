package com.alertetcl.android.ui.live

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF
import android.graphics.Typeface
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
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
private const val STYLE_URL = "https://tiles.openfreemap.org/styles/liberty"

private const val TRANSIT_SRC     = "transit-src"
private const val BUS_SRC         = "bus-src"
private const val VEHICLES_SRC    = "vehicles-src"
private const val STOPS_SRC       = "stops-src"
private const val CLUSTERS_SRC    = "clusters-src"
private const val TRANSIT_LAYER   = "transit-layer"
private const val BUS_LAYER       = "bus-layer"
private const val VEHICLES_LAYER  = "vehicles-layer"
private const val STOPS_LAYER     = "stops-layer"
private const val CLUSTER_CIRCLE  = "cluster-circle-layer"
private const val CLUSTER_TEXT    = "cluster-text-layer"

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
    DisposableEffect(Unit) {
        vm.startPolling()
        onDispose { vm.dispose() }
    }
    val vehicles     by vm.vehicles.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val isLoading    by vm.isLoading.collectAsState()
    val vehiclesError by vm.errorMessage.collectAsState()

    var showLineTraces by remember { mutableStateOf(true) }
    var showStops      by remember { mutableStateOf(false) }

    val transitLines = produceState<List<TransitLine>>(initialValue = emptyList()) {
        value = runCatching { TransitLineService.shared.fetchTransitLines() }.getOrDefault(emptyList())
    }
    val busLines = produceState<List<BusLine>>(initialValue = emptyList()) {
        value = runCatching { BusLineService.shared.fetchBusLines() }.getOrDefault(emptyList())
    }
    val stops = produceState<List<TransitStop>>(initialValue = emptyList(), showStops) {
        if (showStops && value.isEmpty())
            value = runCatching { TransitStopService.shared.fetchStops() }.getOrDefault(emptyList())
    }

    // Animation tick every 100 ms
    var tick by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        while (true) { kotlinx.coroutines.delay(100); tick++ }
    }

    val filteredVehicles by remember {
        derivedStateOf { tick; vehicles.filter { it.vehicleType in selectedTypes } }
    }

    // MapLibre state
    var mapLibreMap  by remember { mutableStateOf<MapLibreMap?>(null) }
    var mapStyle     by remember { mutableStateOf<Style?>(null) }
    var currentZoom  by remember { mutableDoubleStateOf(12.5) }

    // Stable mutable refs readable from non-composable callbacks
    val vehiclesRef = remember { mutableStateOf<List<Vehicle>>(emptyList()) }
    val stopsRef    = remember { mutableStateOf<List<TransitStop>>(emptyList()) }
    vehiclesRef.value = filteredVehicles
    stopsRef.value    = stops.value

    val visibleClusters by remember {
        derivedStateOf {
            if (!showStops) emptyList()
            else ClusteringEngine.cluster(stopsRef.value, max(0.001, 80.0 / 2.0.pow(currentZoom)))
        }
    }

    // Selection state (updated from map click listener on main thread → safe)
    val selectedVehicle = remember { mutableStateOf<Vehicle?>(null) }
    val selectedStop    = remember { mutableStateOf<TransitStop?>(null) }

    // Bottom sheet flags
    var showAlertsSheet      by remember { mutableStateOf(false) }
    var showSettingsSheet    by remember { mutableStateOf(false) }
    var showWidgetStopsSheet by remember { mutableStateOf(false) }
    var showErrorsSheet      by remember { mutableStateOf(false) }

    val mapView = rememberMapView()

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
                        map.addOnCameraIdleListener { currentZoom = map.cameraPosition.zoom }
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
                        map.setStyle(STYLE_URL) { style -> mapStyle = style }
                    }
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Top overlay: progress + error badge + filter chips
        Column(modifier = Modifier.fillMaxWidth().padding(8.dp)) {
            if (isLoading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            if (vehiclesError != null) {
                TextButton(onClick = { showErrorsSheet = true }, modifier = Modifier.padding(top = 4.dp)) {
                    Icon(Icons.Filled.Warning, null, tint = Color(0xFFFF9800), modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("1 source en erreur", fontSize = 12.sp, color = Color(0xFFFF9800))
                }
            }
            Surface(
                shape = RoundedCornerShape(12.dp), tonalElevation = 4.dp,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
            ) {
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()).padding(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    VehicleType.entries.sortedBy { it.sortOrder }.forEach { type ->
                        FilterChip(
                            selected = type in selectedTypes,
                            onClick = { vm.toggleType(type) },
                            label = { Text(type.displayName, fontSize = 12.sp) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = colorFromHex(type.clusterColorHex).copy(alpha = 0.25f)
                            )
                        )
                    }
                    Spacer(Modifier.width(4.dp))
                    FilterChip(selected = showLineTraces, onClick = { showLineTraces = !showLineTraces }, label = { Text("Tracés", fontSize = 12.sp) })
                    FilterChip(selected = showStops,      onClick = { showStops = !showStops },           label = { Text("Arrêts", fontSize = 12.sp) })
                }
            }
        }

        // Bottom-right overlay: count + FABs
        Column(
            modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
            horizontalAlignment = Alignment.End
        ) {
            Surface(shape = RoundedCornerShape(8.dp), tonalElevation = 4.dp) {
                Text("${filteredVehicles.size} véhicules",
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp), fontSize = 12.sp)
            }
            Spacer(Modifier.height(8.dp))
            FilledIconButton(onClick = { showAlertsSheet      = true }) { Icon(Icons.Filled.Warning,  "Alertes") }
            Spacer(Modifier.height(8.dp))
            FilledIconButton(onClick = { showSettingsSheet    = true }) { Icon(Icons.Filled.Settings, "Réglages") }
            Spacer(Modifier.height(8.dp))
            FilledIconButton(onClick = { vm.refresh() })                { Icon(Icons.Filled.Refresh,  "Rafraîchir") }
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

        // Register icons for each unique line (only once per icon)
        filteredVehicles.forEach { v ->
            val iconId = "v_${v.lineName.replace(Regex("[^A-Za-z0-9]"), "_")}"
            if (style.getImage(iconId) == null) style.addImage(iconId, vehicleMarkerBitmap(v.lineName))
        }

        val features = filteredVehicles.map { v ->
            val animated = vm.animatedVehicleFor(v.id)
            val nowSec   = System.currentTimeMillis() / 1000.0
            val coord    = animated?.currentInterpolatedCoordinate(nowSec) ?: v.coordinate
            val iconId   = "v_${v.lineName.replace(Regex("[^A-Za-z0-9]"), "_")}"
            val props    = JsonObject().apply {
                addProperty("id",          v.id)
                addProperty("line",        v.lineName)
                addProperty("destination", v.destination)
                addProperty("icon",        iconId)
            }
            Feature.fromGeometry(Point.fromLngLat(coord.longitude, coord.latitude), props)
        }

        if (style.getSource(VEHICLES_SRC) == null) {
            style.addSource(GeoJsonSource(VEHICLES_SRC, FeatureCollection.fromFeatures(features)))
            style.addLayer(SymbolLayer(VEHICLES_LAYER, VEHICLES_SRC).withProperties(
                PropertyFactory.iconImage(Expression.get("icon")),
                PropertyFactory.iconAllowOverlap(true),
                PropertyFactory.iconIgnorePlacement(true),
                PropertyFactory.iconSize(1f)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(VEHICLES_SRC)?.setGeoJson(FeatureCollection.fromFeatures(features))
        }
    }

    // Stops / clusters
    LaunchedEffect(mapStyle, showStops, visibleClusters) {
        val style = mapStyle ?: return@LaunchedEffect

        val singleFeatures = if (showStops) visibleClusters.filter { it.count == 1 }.map { cl ->
            val s = cl.items.first()
            Feature.fromGeometry(
                Point.fromLngLat(s.coordinate.longitude, s.coordinate.latitude),
                JsonObject().apply { addProperty("id", s.id) }
            )
        } else emptyList()

        val clusterFeatures = if (showStops) visibleClusters.filter { it.count > 1 }.map { cl ->
            Feature.fromGeometry(
                Point.fromLngLat(cl.coordinate.longitude, cl.coordinate.latitude),
                JsonObject().apply { addProperty("count", cl.count) }
            )
        } else emptyList()

        if (style.getSource(STOPS_SRC) == null) {
            style.addSource(GeoJsonSource(STOPS_SRC, FeatureCollection.fromFeatures(singleFeatures)))
            style.addLayer(CircleLayer(STOPS_LAYER, STOPS_SRC).withProperties(
                PropertyFactory.circleColor("#FFFFFF"),
                PropertyFactory.circleRadius(6f),
                PropertyFactory.circleStrokeColor("#1976D2"),
                PropertyFactory.circleStrokeWidth(2f)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(STOPS_SRC)?.setGeoJson(FeatureCollection.fromFeatures(singleFeatures))
        }

        if (style.getSource(CLUSTERS_SRC) == null) {
            style.addSource(GeoJsonSource(CLUSTERS_SRC, FeatureCollection.fromFeatures(clusterFeatures)))
            style.addLayer(CircleLayer(CLUSTER_CIRCLE, CLUSTERS_SRC).withProperties(
                PropertyFactory.circleColor("#1976D2"),
                PropertyFactory.circleRadius(16f)
            ))
            style.addLayer(SymbolLayer(CLUSTER_TEXT, CLUSTERS_SRC).withProperties(
                PropertyFactory.textField(Expression.toString(Expression.get("count"))),
                PropertyFactory.textSize(12f),
                PropertyFactory.textColor("#FFFFFF"),
                PropertyFactory.textAllowOverlap(true),
                PropertyFactory.textIgnorePlacement(true)
            ))
        } else {
            style.getSourceAs<GeoJsonSource>(CLUSTERS_SRC)?.setGeoJson(FeatureCollection.fromFeatures(clusterFeatures))
        }

        val vis = if (showStops) Property.VISIBLE else Property.NONE
        style.getLayer(STOPS_LAYER)?.setProperties(PropertyFactory.visibility(vis))
        style.getLayer(CLUSTER_CIRCLE)?.setProperties(PropertyFactory.visibility(vis))
        style.getLayer(CLUSTER_TEXT)?.setProperties(PropertyFactory.visibility(vis))
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
    if (showSettingsSheet) {
        ModalBottomSheet(onDismissRequest = { showSettingsSheet = false }, sheetState = rememberModalBottomSheetState()) {
            Box(Modifier.fillMaxSize()) {
                com.alertetcl.android.ui.settings.SettingsScreen(onOpenWidgetStops = {
                    showSettingsSheet = false; showWidgetStopsSheet = true
                })
            }
        }
    }
    if (showWidgetStopsSheet) {
        ModalBottomSheet(onDismissRequest = { showWidgetStopsSheet = false }, sheetState = rememberModalBottomSheetState()) {
            Box(Modifier.fillMaxSize()) { com.alertetcl.android.ui.widgetstop.WidgetStopSelectionScreen() }
        }
    }
    if (showErrorsSheet) {
        ModalBottomSheet(onDismissRequest = { showErrorsSheet = false }, sheetState = rememberModalBottomSheetState()) {
            DataSourceErrorsSheet(
                vehiclesError = vehiclesError, alertsError = null,
                onRetryVehicles = { vm.refresh() }, onRetryAlerts = {},
                onDismiss = { showErrorsSheet = false }
            )
        }
    }
}

// ── Detail sheets ────────────────────────────────────────────────────────

@Composable
private fun VehicleDetailSheet(v: Vehicle) {
    Column(modifier = Modifier.padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            LineBadgeMap(v.lineName)
            Spacer(Modifier.width(10.dp))
            Column {
                Text(v.lineName, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(v.vehicleType.displayName, fontSize = 12.sp, color = Color.Gray)
            }
        }
        Spacer(Modifier.height(12.dp))
        Text("→ ${v.destination}", fontSize = 15.sp)
        Spacer(Modifier.height(6.dp))
        val delayColor = when { v.isDelayed -> Color(0xFFE53935); v.isEarly -> Color(0xFFFB8C00); else -> Color(0xFF43A047) }
        Text(v.delayFormatted, color = delayColor, fontWeight = FontWeight.SemiBold)
        v.nextStop?.let { ns ->
            Spacer(Modifier.height(8.dp))
            HorizontalDivider()
            Spacer(Modifier.height(8.dp))
            Text("Prochain arrêt", fontSize = 12.sp, color = Color.Gray)
            Text(ns.stopName ?: ns.stopRef, fontWeight = FontWeight.Medium)
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun StopDetailSheet(stop: TransitStop) {
    val passages = produceState<List<Passage>?>(initialValue = null, stop.id) {
        value = runCatching { TransitStopService.shared.fetchPassagesForStop(stop.id) }.getOrNull() ?: emptyList()
    }
    Column(modifier = Modifier.padding(16.dp)) {
        Text(stop.nom, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        if (stop.commune.isNotEmpty()) Text(stop.commune, fontSize = 12.sp, color = Color.Gray)
        if (stop.pmr) { Spacer(Modifier.height(4.dp)); Text("Accessible PMR", fontSize = 12.sp, color = Color(0xFF1976D2)) }
        Spacer(Modifier.height(12.dp))
        HorizontalDivider()
        Spacer(Modifier.height(8.dp))
        Text("Prochains passages", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        Spacer(Modifier.height(8.dp))
        val list = passages.value
        when {
            list == null    -> Text("Chargement…", fontSize = 13.sp, color = Color.Gray)
            list.isEmpty()  -> Text("Aucun passage à venir", fontSize = 13.sp, color = Color.Gray)
            else            -> LazyColumn(
                contentPadding = PaddingValues(vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.height(280.dp)
            ) { items(list) { p -> PassageRow(p) } }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun PassageRow(p: Passage) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        LineBadgeMap(p.ligne)
        Spacer(Modifier.width(8.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(p.direction, fontSize = 13.sp)
            if (p.isRealTime) Text("Temps réel", fontSize = 10.sp, color = Color(0xFF43A047))
        }
        Text(p.formattedTime, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
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

// ── Bitmap helpers ───────────────────────────────────────────────────────

private fun parseAndroidColor(hex: String): Int {
    val s = hex.removePrefix("#")
    return try { AndroidColor.parseColor(if (s.length == 6 || s.length == 8) "#$s" else "#888888") }
    catch (_: Exception) { AndroidColor.GRAY }
}

private fun vehicleMarkerBitmap(line: String): Bitmap {
    val bg = parseAndroidColor(LineColors.backgroundHex(line))
    val tx = parseAndroidColor(LineColors.textHex(line))
    val w = 110; val h = 64
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val rect = RectF(2f, 2f, (w - 2).toFloat(), (h - 2).toFloat())
    canvas.drawRoundRect(rect, 14f, 14f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg; style = Paint.Style.FILL })
    canvas.drawRoundRect(rect, 14f, 14f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 4f
    })
    canvas.drawText(line, w / 2f, h / 2f + 11f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = tx; textSize = 30f; textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT_BOLD
    })
    return bmp
}
