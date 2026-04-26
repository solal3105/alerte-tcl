package com.alertetcl.android.ui.live

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.alertetcl.shared.viewmodels.LiveVehiclesViewModel
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState

@Composable
fun LiveMapScreen() {
    val vm = remember { LiveVehiclesViewModel() }
    DisposableEffect(Unit) {
        vm.startPolling()
        onDispose { vm.dispose() }
    }
    val vehicles by vm.vehicles.collectAsState()

    val lyon = LatLng(45.764043, 4.835659)
    val cameraState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(lyon, 12.5f)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraState
        ) {
            vehicles.forEach { v ->
                Marker(
                    state = MarkerState(position = LatLng(v.latitude, v.longitude)),
                    title = "${v.lineName} → ${v.destination}",
                    snippet = if (v.isDelayed) "Retard ${v.delayFormatted}" else v.delayFormatted
                )
            }
        }
        Text(
            "${vehicles.size} véhicules",
            modifier = Modifier.align(Alignment.TopStart).padding(12.dp)
        )
    }
}
