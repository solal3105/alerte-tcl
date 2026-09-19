package com.alertetcl.android.ui.map

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.alertetcl.android.ui.components.glass
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.location.modes.CameraMode
import org.maplibre.android.location.modes.RenderMode
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style

// ── Styles de fond de carte ─────────────────────────────────────────────────
// Tuiles OpenFreeMap — 100% gratuit, sans clé API

internal const val STYLE_URL_LIBERTY = "https://tiles.openfreemap.org/styles/liberty"
internal const val STYLE_URL_DARK    = "https://tiles.openfreemap.org/styles/fiord"

/** Satellite via raster ESRI World Imagery (gratuit, sans clé). */
internal const val STYLE_JSON_SATELLITE = """{
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

/** Constructeur de style pour l'état d'affichage courant. */
internal fun mapStyleBuilder(isSatellite: Boolean, isDark: Boolean): Style.Builder = when {
    isSatellite -> Style.Builder().fromJson(STYLE_JSON_SATELLITE)
    isDark      -> Style.Builder().fromUri(STYLE_URL_DARK)
    else        -> Style.Builder().fromUri(STYLE_URL_LIBERTY)
}

// ── Cycle de vie du MapView ─────────────────────────────────────────────────

/**
 * MapView géré par le cycle de vie Compose, avec les contournements matériels obligatoires :
 *
 * - `textureMode(true)` (TextureView) est requis sur Samsung One UI 4.x (Android 12) : le
 *   compositor Samsung crashe avec SurfaceView (« Z-order hole punch ») dans Compose.
 * - Sur émulateur, la densité 420 dpi donne un pixelRatio ~2.6 et fait charger ~7× trop de
 *   tuiles : on force 1.0 pour un rendu fluide (et SurfaceView, plus rapide).
 */
@Composable
internal fun rememberManagedMapView(): MapView {
    val context = LocalContext.current
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

// ── Localisation ────────────────────────────────────────────────────────────

private fun hasLocationPermission(context: Context): Boolean =
    ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED

/** Active le point bleu de position, sans effet si la permission n'est pas accordée. */
internal fun enableLocationComponent(context: Context, map: MapLibreMap, style: Style) {
    if (!hasLocationPermission(context)) return
    @Suppress("MissingPermission")
    map.locationComponent.run {
        activateLocationComponent(
            LocationComponentActivationOptions.builder(context, style)
                .useDefaultLocationEngine(true)
                .build()
        )
        isLocationComponentEnabled = true
        renderMode = RenderMode.COMPASS
        cameraMode = CameraMode.NONE
    }
}

/** Recentre la caméra sur la dernière position connue (GPS ou réseau, la plus récente). */
internal fun recenterOnUser(context: Context, map: MapLibreMap?) {
    val m = map ?: return
    if (!hasLocationPermission(context)) return
    val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
    @Suppress("MissingPermission")
    val loc = listOfNotNull(
        runCatching { lm.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull(),
        runCatching { lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull()
    ).maxByOrNull { it.time } ?: return
    m.animateCamera(
        CameraUpdateFactory.newCameraPosition(
            CameraPosition.Builder()
                .target(LatLng(loc.latitude, loc.longitude))
                .zoom(15.0)
                .build()
        )
    )
}

// ── Contrôles ───────────────────────────────────────────────────────────────

/** Bouton rond des contrôles carte (recentrage, satellite, filtres…). */
@Composable
internal fun MapCircleFab(
    icon: ImageVector,
    contentDesc: String,
    tint: Color,
    onClick: () -> Unit
) {
    SmallFloatingActionButton(
        onClick = onClick,
        shape = CircleShape,
        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f),
        contentColor = tint,
        modifier = Modifier.glass(CircleShape, alpha = 0f),
    ) {
        Icon(icon, contentDesc, modifier = Modifier.size(22.dp))
    }
}
