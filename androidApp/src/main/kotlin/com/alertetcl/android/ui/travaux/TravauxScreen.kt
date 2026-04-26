package com.alertetcl.android.ui.travaux

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.Typeface
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.alertetcl.shared.models.Travaux
import com.alertetcl.shared.models.TravauxAvancement
import com.alertetcl.shared.models.TravauxImportance
import com.alertetcl.shared.models.TravauxType
import com.alertetcl.shared.viewmodels.TravauxViewModel
import com.google.gson.JsonObject
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import org.maplibre.geojson.Polygon

private const val STYLE_URL    = "https://tiles.openfreemap.org/styles/liberty"
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
private const val POLY_SRC     = "travaux-poly-src"
private const val OUTLINE_SRC  = "travaux-outline-src"
private const val MARKERS_SRC  = "travaux-markers-src"
private const val POLY_LAYER   = "travaux-poly-layer"
private const val OUTLINE_LAYER = "travaux-outline-layer"
private const val MARKERS_LAYER = "travaux-markers-layer"

@Composable
private fun rememberTravauxMapView(): MapView {
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TravauxScreen() {
    val vm = remember { TravauxViewModel() }
    val context = LocalContext.current
    DisposableEffect(Unit) { onDispose { vm.dispose() } }
    LaunchedEffect(Unit) { vm.refresh() }

    val travaux by vm.travaux.collectAsState()
    val isLoading by vm.isLoading.collectAsState()
    val errorMsg by vm.errorMessage.collectAsState()
    var selected by remember { mutableStateOf<Travaux?>(null) }

    var mapLibreMap by remember { mutableStateOf<MapLibreMap?>(null) }
    var mapStyle by remember { mutableStateOf<Style?>(null) }
    var currentZoom by remember { mutableDoubleStateOf(12.5) }
    var isSatellite by remember { mutableStateOf(false) }
    var showFilterSheet by remember { mutableStateOf(false) }

    // Local filter state (shared VM ne porte pas les filtres)
    var selectedImportances by remember { mutableStateOf(TravauxImportance.entries.toSet()) }
    var selectedTypes by remember { mutableStateOf(TravauxType.entries.toSet()) }
    var selectedAvancements by remember { mutableStateOf(TravauxAvancement.entries.toSet()) }
    val hasActiveFilters = selectedImportances.size != TravauxImportance.entries.size ||
            selectedTypes.size != TravauxType.entries.size ||
            selectedAvancements.size != TravauxAvancement.entries.size

    val filteredTravaux = remember(travaux, selectedImportances, selectedTypes, selectedAvancements) {
        travaux.filter {
            it.importance in selectedImportances &&
            it.type in selectedTypes &&
            it.avancement in selectedAvancements
        }
    }

    val travauxRef = remember { mutableStateOf<List<Travaux>>(emptyList()) }
    travauxRef.value = filteredTravaux

    val locationPermLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) recenterMapOnUser(context, mapLibreMap) }

    val mapView = rememberTravauxMapView()

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
                            .zoom(12.5)
                            .build()
                        map.addOnCameraIdleListener { currentZoom = map.cameraPosition.zoom }
                        map.addOnMapClickListener { latLng ->
                            val screen = map.projection.toScreenLocation(latLng)
                            val pt = PointF(screen.x, screen.y)
                            val hits = map.queryRenderedFeatures(pt, MARKERS_LAYER)
                            if (hits.isNotEmpty()) {
                                val id = hits[0].getStringProperty("id")
                                selected = travauxRef.value.find { it.id == id }
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
        }

        // Center loading overlay (only when empty)
        if (isLoading && travaux.isEmpty()) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = Color.White.copy(alpha = 0.94f),
                shadowElevation = 8.dp,
                modifier = Modifier.align(Alignment.Center).padding(24.dp)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    CircularProgressIndicator()
                    Text("Chargement des travaux…", fontSize = 14.sp, color = Color(0xFF6E6E73))
                }
            }
        }
        // Error overlay
        if (errorMsg != null && travaux.isEmpty() && !isLoading) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = Color.White.copy(alpha = 0.96f),
                shadowElevation = 8.dp,
                modifier = Modifier.align(Alignment.Center).padding(24.dp)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Icon(Icons.Filled.CloudOff, null, tint = Color(0xFFFF9500), modifier = Modifier.size(40.dp))
                    Text("Données temporairement indisponibles", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        errorMsg ?: "Erreur",
                        fontSize = 12.sp, color = Color(0xFF6E6E73),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                    TextButton(onClick = { vm.refresh(force = true) }) { Text("Réessayer") }
                }
            }
        }

        // Bottom-right FABs (3) — parité iOS
        Column(
            modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            TravauxCircleFab(
                icon = Icons.Filled.Public, contentDesc = "Vue satellite",
                tint = if (isSatellite) Color(0xFFFF9500) else Color(0xFF1C1C1E),
                onClick = { isSatellite = !isSatellite }
            )
            TravauxCircleFab(
                icon = Icons.Filled.FilterList, contentDesc = "Filtres",
                tint = if (hasActiveFilters) Color(0xFFFF9500) else Color(0xFF1C1C1E),
                onClick = { showFilterSheet = true }
            )
            TravauxCircleFab(
                icon = Icons.Filled.MyLocation, contentDesc = "Ma position",
                tint = Color(0xFF007AFF),
                onClick = {
                    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
                        context, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) recenterMapOnUser(context, mapLibreMap)
                    else locationPermLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                }
            )
        }
    }

    // Update polygons + markers on style/travaux change
    LaunchedEffect(mapStyle, filteredTravaux) {
        val style = mapStyle ?: return@LaunchedEffect
        val tx = filteredTravaux

        val polyFeatures = tx.flatMap { t ->
            val (fillHex, _) = travauxColorHex(t.importance)
            t.polygons.mapNotNull { ring ->
                if (ring.size < 3) null
                else {
                    val outer = ring.map { c -> Point.fromLngLat(c.longitude, c.latitude) }
                    val props = JsonObject().apply {
                        addProperty("id", t.id)
                        addProperty("fill", fillHex)
                    }
                    Feature.fromGeometry(Polygon.fromLngLats(listOf(outer)), props)
                }
            }
        }
        val outlineFeatures = tx.flatMap { t ->
            val (_, strokeHex) = travauxColorHex(t.importance)
            t.polygons.mapNotNull { ring ->
                if (ring.size < 3) null
                else {
                    val pts = ring.map { c -> Point.fromLngLat(c.longitude, c.latitude) }
                    val props = JsonObject().apply { addProperty("stroke", strokeHex) }
                    Feature.fromGeometry(LineString.fromLngLats(pts), props)
                }
            }
        }
        val markerFeatures = tx.map { t ->
            val props = JsonObject().apply {
                addProperty("id", t.id)
                addProperty("icon", travauxIconId(t.importance))
            }
            Feature.fromGeometry(Point.fromLngLat(t.centroid.longitude, t.centroid.latitude), props)
        }

        if (style.getSource(POLY_SRC) == null) {
            style.addSource(GeoJsonSource(POLY_SRC, FeatureCollection.fromFeatures(polyFeatures)))
            style.addLayer(FillLayer(POLY_LAYER, POLY_SRC).withProperties(
                PropertyFactory.fillColor(org.maplibre.android.style.expressions.Expression.get("fill")),
                PropertyFactory.fillOpacity(0.35f)
            ))
        } else style.getSourceAs<GeoJsonSource>(POLY_SRC)?.setGeoJson(FeatureCollection.fromFeatures(polyFeatures))

        if (style.getSource(OUTLINE_SRC) == null) {
            style.addSource(GeoJsonSource(OUTLINE_SRC, FeatureCollection.fromFeatures(outlineFeatures)))
            style.addLayer(LineLayer(OUTLINE_LAYER, OUTLINE_SRC).withProperties(
                PropertyFactory.lineColor(org.maplibre.android.style.expressions.Expression.get("stroke")),
                PropertyFactory.lineWidth(3f),
                PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)
            ))
        } else style.getSourceAs<GeoJsonSource>(OUTLINE_SRC)?.setGeoJson(FeatureCollection.fromFeatures(outlineFeatures))

        if (style.getSource(MARKERS_SRC) == null) {
            TravauxImportance.entries.forEach { imp ->
                val iconId = travauxIconId(imp)
                if (style.getImage(iconId) == null)
                    style.addImage(iconId, travauxMarkerBitmap(imp))
            }
            style.addSource(GeoJsonSource(MARKERS_SRC, FeatureCollection.fromFeatures(markerFeatures)))
            style.addLayer(SymbolLayer(MARKERS_LAYER, MARKERS_SRC).withProperties(
                PropertyFactory.iconImage(org.maplibre.android.style.expressions.Expression.get("icon")),
                PropertyFactory.iconAllowOverlap(true),
                PropertyFactory.iconIgnorePlacement(true),
                PropertyFactory.iconAnchor("bottom"),
                PropertyFactory.iconSize(1f)
            ))
        } else style.getSourceAs<GeoJsonSource>(MARKERS_SRC)?.setGeoJson(FeatureCollection.fromFeatures(markerFeatures))
    }

    // Show polygons only when zoomed in enough (iOS parity)
    LaunchedEffect(mapStyle, currentZoom) {
        val style = mapStyle ?: return@LaunchedEffect
        val vis = if (currentZoom > 13.0) Property.VISIBLE else Property.NONE
        style.getLayer(POLY_LAYER)?.setProperties(PropertyFactory.visibility(vis))
        style.getLayer(OUTLINE_LAYER)?.setProperties(PropertyFactory.visibility(vis))
    }

    if (showFilterSheet) {
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            sheetState = rememberModalBottomSheetState()
        ) {
            TravauxFiltersSheet(
                selectedImportances = selectedImportances,
                onToggleImportance = { imp ->
                    val s = selectedImportances.toMutableSet()
                    if (!s.add(imp)) s.remove(imp); selectedImportances = s
                },
                selectedTypes = selectedTypes,
                onToggleType = { t ->
                    val s = selectedTypes.toMutableSet()
                    if (!s.add(t)) s.remove(t); selectedTypes = s
                },
                selectedAvancements = selectedAvancements,
                onToggleAvancement = { a ->
                    val s = selectedAvancements.toMutableSet()
                    if (!s.add(a)) s.remove(a); selectedAvancements = s
                },
                onReset = {
                    selectedImportances = TravauxImportance.entries.toSet()
                    selectedTypes = TravauxType.entries.toSet()
                    selectedAvancements = TravauxAvancement.entries.toSet()
                }
            )
        }
    }

    selected?.let { t ->
        ModalBottomSheet(
            onDismissRequest = { selected = null },
            sheetState = rememberModalBottomSheetState()
        ) { TravauxDetailSheet(t) }
    }
}

@Composable
private fun TravauxCircleFab(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDesc: String,
    tint: Color,
    onClick: () -> Unit
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

@Composable
private fun TravauxFiltersSheet(
    selectedImportances: Set<TravauxImportance>,
    onToggleImportance: (TravauxImportance) -> Unit,
    selectedTypes: Set<TravauxType>,
    onToggleType: (TravauxType) -> Unit,
    selectedAvancements: Set<TravauxAvancement>,
    onToggleAvancement: (TravauxAvancement) -> Unit,
    onReset: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Filtres", fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            TextButton(onClick = onReset) { Text("Réinitialiser") }
        }

        Text("Importance", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF8E8E93))
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            TravauxImportance.entries.forEach { imp ->
                FilterChip(
                    selected = imp in selectedImportances,
                    onClick = { onToggleImportance(imp) },
                    label = { Text(imp.displayName, fontSize = 12.sp) }
                )
            }
        }

        HorizontalDivider()
        Text("Type de chantier", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF8E8E93))
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            TravauxType.entries.forEach { t ->
                FilterChip(
                    selected = t in selectedTypes,
                    onClick = { onToggleType(t) },
                    label = { Text(t.displayName, fontSize = 12.sp) }
                )
            }
        }

        HorizontalDivider()
        Text("Avancement", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF8E8E93))
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            TravauxAvancement.entries.forEach { a ->
                FilterChip(
                    selected = a in selectedAvancements,
                    onClick = { onToggleAvancement(a) },
                    label = { Text(a.displayName, fontSize = 12.sp) }
                )
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

private fun recenterMapOnUser(context: android.content.Context, map: MapLibreMap?) {
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
private fun TravauxDetailSheet(t: Travaux) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text(t.nomChantier.ifEmpty { t.nom },
            fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(t.commune, fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(8.dp))
        ImportanceBadge(t.importance)
        Spacer(Modifier.height(8.dp))
        Text("Type      : ${t.type.displayName}", fontSize = 13.sp)
        Text("Nature    : ${t.natureChantier.displayName}", fontSize = 13.sp)
        Text("Avancement : ${t.avancement.displayName}", fontSize = 13.sp)
        Text("Perturb.   : ${t.typePerturbation.raw}", fontSize = 13.sp)
        if (t.intervenant.isNotEmpty()) {
            Text("Intervenant: ${t.intervenant}", fontSize = 13.sp, color = Color.Gray)
        }
        t.precisionLocalisation?.let {
            Spacer(Modifier.height(6.dp))
            Text(it, fontSize = 12.sp, color = Color.Gray)
        }

        val now = System.currentTimeMillis() / 1000L
        val pct = t.completionPercentage(now)
        Spacer(Modifier.height(10.dp))
        HorizontalDivider()
        Spacer(Modifier.height(6.dp))
        Text("Progression : ${"%.0f".format(pct)} %", fontSize = 13.sp, fontWeight = FontWeight.Medium)
        t.description?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, fontSize = 12.sp)
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun ImportanceBadge(imp: TravauxImportance) {
    val (label, c) = when (imp) {
        TravauxImportance.TRES_PERTURBANT -> "Très perturbant" to Color(0xFFE53935)
        TravauxImportance.PERTURBANT      -> "Perturbant"      to Color(0xFFFB8C00)
        TravauxImportance.PEU_PERTURBANT  -> "Peu perturbant"  to Color(0xFF43A047)
        TravauxImportance.INCONNU         -> "Non défini"      to Color.Gray
    }
    Surface(color = c.copy(alpha = 0.18f), shape = RoundedCornerShape(8.dp)) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = c
        )
    }
}

private fun travauxColorHex(imp: TravauxImportance): Pair<String, String> {
    val base = when (imp) {
        TravauxImportance.TRES_PERTURBANT -> "#E53935"
        TravauxImportance.PERTURBANT      -> "#FB8C00"
        TravauxImportance.PEU_PERTURBANT  -> "#43A047"
        TravauxImportance.INCONNU         -> "#6E6E73"
    }
    return base to base
}

private fun travauxIconId(imp: TravauxImportance) = "travaux_${imp.name}"

/** Marker iso iOS : disque coloré + icone H + badge importance (rouge "!" / orange) en haut-droite. */
private fun travauxMarkerBitmap(imp: TravauxImportance): Bitmap {
    val s = 80; val cx = s / 2f; val cy = s / 2f
    val baseColor = when (imp) {
        TravauxImportance.TRES_PERTURBANT -> AndroidColor.parseColor("#E53935")
        TravauxImportance.PERTURBANT      -> AndroidColor.parseColor("#FB8C00")
        TravauxImportance.PEU_PERTURBANT  -> AndroidColor.parseColor("#43A047")
        TravauxImportance.INCONNU         -> AndroidColor.parseColor("#6E6E73")
    }
    val bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val mainR = 26f
    canvas.drawCircle(cx, cy, mainR, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = baseColor; style = Paint.Style.FILL })
    canvas.drawCircle(cx, cy, mainR, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 3f
    })
    // Letter "H" (chantier / hammer) centered
    canvas.drawText("H", cx, cy + 10f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; textSize = 28f; textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    })
    // Importance badge top-right (offset like iOS x:12, y:-12)
    when (imp) {
        TravauxImportance.TRES_PERTURBANT -> {
            val br = 11f; val bx = cx + 18f; val by = cy - 18f
            canvas.drawCircle(bx, by, br, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = AndroidColor.parseColor("#E53935"); style = Paint.Style.FILL
            })
            canvas.drawCircle(bx, by, br, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 2f
            })
            canvas.drawText("!", bx, by + 6f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = AndroidColor.WHITE; textSize = 16f; textAlign = Paint.Align.CENTER
                typeface = Typeface.DEFAULT_BOLD
            })
        }
        TravauxImportance.PERTURBANT -> {
            val br = 9f; val bx = cx + 18f; val by = cy - 18f
            canvas.drawCircle(bx, by, br, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = AndroidColor.parseColor("#FB8C00"); style = Paint.Style.FILL
            })
            canvas.drawCircle(bx, by, br, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 2f
            })
        }
        else -> {}
    }
    return bmp
}
