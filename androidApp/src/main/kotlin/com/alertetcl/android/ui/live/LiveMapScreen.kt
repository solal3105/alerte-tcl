package com.alertetcl.android.ui.live

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
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
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polyline
import com.google.maps.android.compose.rememberCameraPositionState
import kotlin.math.max
import kotlin.math.pow

private val LYON = LatLng(45.764043, 4.835659)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveMapScreen() {
    val vm = remember { LiveVehiclesViewModel() }
    DisposableEffect(Unit) {
        vm.startPolling()
        onDispose { vm.dispose() }
    }
    val vehicles by vm.vehicles.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val isLoading by vm.isLoading.collectAsState()

    val cameraState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(LYON, 12.5f)
    }

    var showLineTraces by remember { mutableStateOf(true) }
    var showStops by remember { mutableStateOf(false) }

    val transitLines = produceState<List<TransitLine>>(initialValue = emptyList()) {
        value = runCatching { TransitLineService.shared.fetchTransitLines() }.getOrDefault(emptyList())
    }
    val busLines = produceState<List<BusLine>>(initialValue = emptyList()) {
        value = runCatching { BusLineService.shared.fetchBusLines() }.getOrDefault(emptyList())
    }
    val stops = produceState<List<TransitStop>>(initialValue = emptyList(), showStops) {
        if (showStops && value.isEmpty()) {
            value = runCatching { TransitStopService.shared.fetchStops() }.getOrDefault(emptyList())
        }
    }

    var tick by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(100)
            tick++
        }
    }

    val filteredVehicles by remember {
        derivedStateOf {
            tick // dépendance
            vehicles.filter { it.vehicleType in selectedTypes }
        }
    }

    val visibleClusters by remember {
        derivedStateOf {
            if (!showStops) emptyList()
            else {
                val zoom = cameraState.position.zoom
                val deltaLat = max(0.001, 80.0 / 2.0.pow(zoom.toDouble()))
                ClusteringEngine.cluster(stops.value, deltaLat)
            }
        }
    }

    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }
    var selectedStop by remember { mutableStateOf<TransitStop?>(null) }

    Box(modifier = Modifier.fillMaxSize()) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraState,
            properties = MapProperties(),
            uiSettings = MapUiSettings(zoomControlsEnabled = false, compassEnabled = true)
        ) {
            if (showLineTraces) {
                transitLines.value.forEach { line ->
                    val pts = line.coordinates.mapNotNull { c ->
                        if (c.size < 2) null else LatLng(c[1], c[0])
                    }
                    if (pts.size >= 2) {
                        Polyline(
                            points = pts,
                            color = colorFromHex(line.strokeColorHex),
                            width = 8f,
                            zIndex = 1f
                        )
                    }
                }
                busLines.value.forEach { line ->
                    val pts = line.coordinates.mapNotNull { c ->
                        if (c.size < 2) null else LatLng(c[1], c[0])
                    }
                    if (pts.size >= 2) {
                        Polyline(
                            points = pts,
                            color = colorFromHex(LineColors.routeStrokeHex(line.name)),
                            width = 4f,
                            zIndex = 0f
                        )
                    }
                }
            }

            if (showStops) {
                visibleClusters.forEach { cluster ->
                    val pos = LatLng(cluster.coordinate.latitude, cluster.coordinate.longitude)
                    if (cluster.count == 1) {
                        val stop = cluster.items.first()
                        Marker(
                            state = MarkerState(position = pos),
                            title = stop.nom,
                            snippet = stop.commune,
                            icon = stopMarker(),
                            onClick = { selectedStop = stop; true }
                        )
                    } else {
                        Marker(
                            state = MarkerState(position = pos),
                            title = "${cluster.count} arrêts",
                            icon = clusterMarker(cluster.count),
                            onClick = { false }
                        )
                    }
                }
            }

            filteredVehicles.forEach { v ->
                val animated = vm.animatedVehicleFor(v.id)
                val nowSec = System.currentTimeMillis() / 1000.0
                val coord = animated?.currentInterpolatedCoordinate(nowSec) ?: v.coordinate
                Marker(
                    state = MarkerState(position = LatLng(coord.latitude, coord.longitude)),
                    title = "${v.lineName} → ${v.destination}",
                    icon = vehicleMarker(v.lineName),
                    zIndex = 5f,
                    onClick = { selectedVehicle = v; true }
                )
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            if (isLoading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())

            Surface(
                shape = RoundedCornerShape(12.dp),
                tonalElevation = 4.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
            ) {
                Row(
                    modifier = Modifier
                        .horizontalScroll(rememberScrollState())
                        .padding(8.dp),
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
                    FilterChip(
                        selected = showLineTraces,
                        onClick = { showLineTraces = !showLineTraces },
                        label = { Text("Tracés", fontSize = 12.sp) }
                    )
                    FilterChip(
                        selected = showStops,
                        onClick = { showStops = !showStops },
                        label = { Text("Arrêts", fontSize = 12.sp) }
                    )
                }
            }
        }

        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp),
            horizontalAlignment = Alignment.End
        ) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                tonalElevation = 4.dp
            ) {
                Text(
                    "${filteredVehicles.size} véhicules",
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    fontSize = 12.sp
                )
            }
            Spacer(Modifier.height(8.dp))
            FilledIconButton(onClick = { vm.refresh() }) {
                Icon(Icons.Filled.Refresh, contentDescription = "Rafraîchir")
            }
        }
    }

    selectedVehicle?.let { v ->
        ModalBottomSheet(
            onDismissRequest = { selectedVehicle = null },
            sheetState = rememberModalBottomSheetState()
        ) { VehicleDetailSheet(v) }
    }
    selectedStop?.let { stop ->
        ModalBottomSheet(
            onDismissRequest = { selectedStop = null },
            sheetState = rememberModalBottomSheetState()
        ) { StopDetailSheet(stop) }
    }
}

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
        val delayColor = when {
            v.isDelayed -> Color(0xFFE53935)
            v.isEarly   -> Color(0xFFFB8C00)
            else        -> Color(0xFF43A047)
        }
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
        if (stop.pmr) {
            Spacer(Modifier.height(4.dp))
            Text("Accessible PMR", fontSize = 12.sp, color = Color(0xFF1976D2))
        }
        Spacer(Modifier.height(12.dp))
        HorizontalDivider()
        Spacer(Modifier.height(8.dp))
        Text("Prochains passages", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        Spacer(Modifier.height(8.dp))
        val list = passages.value
        when {
            list == null -> Text("Chargement…", fontSize = 13.sp, color = Color.Gray)
            list.isEmpty() -> Text("Aucun passage à venir", fontSize = 13.sp, color = Color.Gray)
            else -> LazyColumn(
                contentPadding = PaddingValues(vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.height(280.dp)
            ) {
                items(list) { p -> PassageRow(p) }
            }
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
        modifier = Modifier
            .size(width = 38.dp, height = 22.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(colorFromHex(LineColors.backgroundHex(line))),
        contentAlignment = Alignment.Center
    ) {
        Text(line, color = colorFromHex(LineColors.textHex(line)), fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

private fun parseAndroidColor(hex: String): Int {
    val s = hex.removePrefix("#")
    return AndroidColor.parseColor(if (s.length == 6 || s.length == 8) "#$s" else "#888888")
}

@Composable
private fun vehicleMarker(line: String) =
    remember(line) {
        val bg = parseAndroidColor(LineColors.backgroundHex(line))
        val tx = parseAndroidColor(LineColors.textHex(line))
        val w = 110; val h = 64
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val rect = RectF(2f, 2f, (w - 2).toFloat(), (h - 2).toFloat())
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg; style = Paint.Style.FILL }
        canvas.drawRoundRect(rect, 14f, 14f, paint)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 4f
        }
        canvas.drawRoundRect(rect, 14f, 14f, border)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = tx; textSize = 30f; textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }
        canvas.drawText(line, w / 2f, h / 2f + 11f, text)
        BitmapDescriptorFactory.fromBitmap(bmp)
    }

@Composable
private fun stopMarker() = remember {
    val s = 22
    val bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; style = Paint.Style.FILL }
    canvas.drawCircle(s / 2f, s / 2f, s / 2f - 1f, paint)
    val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.parseColor("#1976D2")
        style = Paint.Style.STROKE; strokeWidth = 3f
    }
    canvas.drawCircle(s / 2f, s / 2f, s / 2f - 2f, border)
    BitmapDescriptorFactory.fromBitmap(bmp)
}

@Composable
private fun clusterMarker(count: Int) = remember(count) {
    val s = 56
    val bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.parseColor("#1976D2"); style = Paint.Style.FILL
    }
    canvas.drawCircle(s / 2f, s / 2f, s / 2f - 2f, paint)
    val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 4f
    }
    canvas.drawCircle(s / 2f, s / 2f, s / 2f - 4f, border)
    val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE; textSize = 22f; textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
    }
    canvas.drawText(count.toString(), s / 2f, s / 2f + 8f, text)
    BitmapDescriptorFactory.fromBitmap(bmp)
}
