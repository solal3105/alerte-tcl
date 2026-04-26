package com.alertetcl.android.ui.travaux

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.shared.models.Travaux
import com.alertetcl.shared.models.TravauxImportance
import com.alertetcl.shared.viewmodels.TravauxViewModel
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polygon
import com.google.maps.android.compose.rememberCameraPositionState

private val LYON = LatLng(45.764043, 4.835659)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TravauxScreen() {
    val vm = remember { TravauxViewModel() }
    DisposableEffect(Unit) { onDispose { vm.dispose() } }

    LaunchedEffect(Unit) { vm.refresh() }

    val travaux by vm.travaux.collectAsState()
    val isLoading by vm.isLoading.collectAsState()

    val cameraState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(LYON, 12.5f)
    }
    var selected by remember { mutableStateOf<Travaux?>(null) }

    Box(modifier = Modifier.fillMaxSize()) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraState,
            uiSettings = MapUiSettings(zoomControlsEnabled = false)
        ) {
            travaux.forEach { t ->
                val (fill, stroke) = travauxColors(t.importance)
                t.polygons.forEach { ring ->
                    if (ring.size >= 3) {
                        Polygon(
                            points = ring.map { LatLng(it.latitude, it.longitude) },
                            fillColor = fill,
                            strokeColor = stroke,
                            strokeWidth = 4f
                        )
                    }
                }
                Marker(
                    state = MarkerState(position = LatLng(t.centroid.latitude, t.centroid.longitude)),
                    title = t.nomChantier.ifEmpty { t.nom },
                    snippet = t.commune,
                    onClick = { selected = t; true }
                )
            }
        }

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

private fun travauxColors(imp: TravauxImportance): Pair<Color, Color> {
    val base = when (imp) {
        TravauxImportance.TRES_PERTURBANT -> Color(0xFFE53935)
        TravauxImportance.PERTURBANT      -> Color(0xFFFB8C00)
        TravauxImportance.PEU_PERTURBANT  -> Color(0xFF43A047)
        TravauxImportance.INCONNU         -> Color(0xFF6E6E73)
    }
    return base.copy(alpha = 0.30f) to base
}
