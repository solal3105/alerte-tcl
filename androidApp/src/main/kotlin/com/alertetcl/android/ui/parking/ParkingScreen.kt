package com.alertetcl.android.ui.parking

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.PointF
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
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
import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.geo.LatLng as GeoLatLng
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.viewmodels.ParkingViewModel
import com.google.gson.JsonObject
import org.maplibre.android.camera.CameraPosition
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
    DisposableEffect(Unit) { onDispose { vm.dispose() } }

    val parkings by vm.parkings.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val showParcRelais by vm.showParcRelais.collectAsState()
    val isLoading by vm.isLoading.collectAsState()

    var mapLibreMap by remember { mutableStateOf<MapLibreMap?>(null) }
    var mapStyle by remember { mutableStateOf<Style?>(null) }

    val parkingsRef = remember { mutableStateOf<List<Parking>>(emptyList()) }
    parkingsRef.value = parkings

    var selectedParking by remember { mutableStateOf<Parking?>(null) }

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

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            if (isLoading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            Surface(
                shape = RoundedCornerShape(12.dp),
                tonalElevation = 4.dp,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
            ) {
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()).padding(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ParkingType.entries.forEach { type ->
                        FilterChip(
                            selected = type in selectedTypes,
                            onClick = { vm.toggleType(type) },
                            label = { Text(type.displayName, fontSize = 12.sp) }
                        )
                    }
                    Spacer(Modifier.width(4.dp))
                    FilterChip(
                        selected = showParcRelais,
                        onClick = { vm.toggleParcRelais() },
                        label = { Text("Parc Relais (P+R)", fontSize = 12.sp) }
                    )
                }
            }
        }

        Surface(
            shape = RoundedCornerShape(8.dp),
            tonalElevation = 4.dp,
            modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp)
        ) {
            Text(
                "${parkings.size} parkings",
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                fontSize = 12.sp
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

        // Register icons (one per availability × isParcRelais combo)
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
