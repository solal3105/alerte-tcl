package com.alertetcl.android.ui.parking

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
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
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.geo.LatLng as GeoLatLng
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.viewmodels.ParkingViewModel
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged

private val LYON = LatLng(45.764043, 4.835659)

@OptIn(ExperimentalMaterial3Api::class, kotlinx.coroutines.FlowPreview::class)
@Composable
fun ParkingScreen() {
    val vm = remember { ParkingViewModel() }
    DisposableEffect(Unit) { onDispose { vm.dispose() } }

    val parkings by vm.parkings.collectAsState()
    val selectedTypes by vm.selectedTypes.collectAsState()
    val showParcRelais by vm.showParcRelais.collectAsState()
    val isLoading by vm.isLoading.collectAsState()

    val cameraState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(LYON, 13f)
    }

    // Recharge automatique sur changement de viewport (debounce 500 ms)
    LaunchedEffect(selectedTypes, showParcRelais) {
        snapshotFlow { cameraState.position }
            .distinctUntilChanged()
            .debounce(500)
            .collect { pos ->
                val zoom = pos.zoom
                val deltaLat = 0.6 / Math.pow(2.0, (zoom - 8.0))
                val deltaLng = deltaLat
                val region = GeoRegion(
                    center = GeoLatLng(pos.target.latitude, pos.target.longitude),
                    latitudeDelta = deltaLat,
                    longitudeDelta = deltaLng
                )
                vm.loadInRegion(region)
            }
    }

    var selectedParking by remember { mutableStateOf<Parking?>(null) }

    Box(modifier = Modifier.fillMaxSize()) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraState,
            uiSettings = MapUiSettings(zoomControlsEnabled = false)
        ) {
            parkings.forEach { p ->
                Marker(
                    state = MarkerState(position = LatLng(p.latitude, p.longitude)),
                    title = p.nom,
                    snippet = if (p.hasRealtimeData) "${p.placesDisponibles}/${p.capaciteTotale}" else "Statique",
                    icon = parkingMarker(p.availabilityColor, p.isParcRelais),
                    onClick = { selectedParking = p; true }
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

@Composable
private fun parkingMarker(color: AvailabilityColor, isParcRelais: Boolean) =
    remember(color, isParcRelais) {
        val s = 56
        val bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = parkingAndroidColor(color); style = Paint.Style.FILL
        }
        canvas.drawCircle(s / 2f, s / 2f, s / 2f - 2f, paint)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 4f
        }
        canvas.drawCircle(s / 2f, s / 2f, s / 2f - 4f, border)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = AndroidColor.WHITE; textSize = 26f; textAlign = Paint.Align.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        canvas.drawText(if (isParcRelais) "P+R" else "P", s / 2f, s / 2f + 9f, text)
        BitmapDescriptorFactory.fromBitmap(bmp)
    }
