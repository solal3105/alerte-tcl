package com.alertetcl.android.ui.travaux

import android.graphics.PointF
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import com.alertetcl.shared.models.TravauxImportance
import com.alertetcl.shared.viewmodels.TravauxViewModel
import com.google.gson.JsonObject
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import org.maplibre.geojson.Polygon

private const val STYLE_URL    = "https://tiles.openfreemap.org/styles/liberty"
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
    DisposableEffect(Unit) { onDispose { vm.dispose() } }
    LaunchedEffect(Unit) { vm.refresh() }

    val travaux by vm.travaux.collectAsState()
    val isLoading by vm.isLoading.collectAsState()
    var selected by remember { mutableStateOf<Travaux?>(null) }

    var mapLibreMap by remember { mutableStateOf<MapLibreMap?>(null) }
    var mapStyle by remember { mutableStateOf<Style?>(null) }

    val travauxRef = remember { mutableStateOf<List<Travaux>>(emptyList()) }
    travauxRef.value = travaux

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

        Column(
            modifier = Modifier.fillMaxWidth().padding(8.dp)
        ) {
            if (isLoading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            Surface(
                shape = RoundedCornerShape(8.dp),
                tonalElevation = 4.dp,
                modifier = Modifier.padding(top = 8.dp)
            ) {
                Text(
                    "${travaux.size} chantiers",
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    fontSize = 12.sp
                )
            }
        }
    }

    // Update polygons + markers on style/travaux change
    LaunchedEffect(mapStyle, travaux) {
        val style = mapStyle ?: return@LaunchedEffect

        // Polygon fills
        val polyFeatures = travaux.flatMap { t ->
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
        // Outline (same rings as LineString for stroke)
        val outlineFeatures = travaux.flatMap { t ->
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
        // Centroid markers
        val markerFeatures = travaux.map { t ->
            val props = JsonObject().apply {
                addProperty("id", t.id)
                addProperty("color", travauxColorHex(t.importance).second)
            }
            Feature.fromGeometry(Point.fromLngLat(t.centroid.longitude, t.centroid.latitude), props)
        }

        org.maplibre.android.style.expressions.Expression.get("fill")

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
            style.addSource(GeoJsonSource(MARKERS_SRC, FeatureCollection.fromFeatures(markerFeatures)))
            style.addLayer(CircleLayer(MARKERS_LAYER, MARKERS_SRC).withProperties(
                PropertyFactory.circleColor(org.maplibre.android.style.expressions.Expression.get("color")),
                PropertyFactory.circleRadius(10f),
                PropertyFactory.circleStrokeColor("#FFFFFF"),
                PropertyFactory.circleStrokeWidth(2f)
            ))
        } else style.getSourceAs<GeoJsonSource>(MARKERS_SRC)?.setGeoJson(FeatureCollection.fromFeatures(markerFeatures))
    }

    selected?.let { t ->
        ModalBottomSheet(
            onDismissRequest = { selected = null },
            sheetState = rememberModalBottomSheetState()
        ) { TravauxDetailSheet(t) }
    }
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
