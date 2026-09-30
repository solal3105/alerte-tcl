package com.alertetcl.android.ui.map

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Looper
import android.os.SystemClock
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.theme.Tokens
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

/** Position précise ou approximative : Android 12+ laisse l'utilisateur n'accorder que la seconde. */
internal val LOCATION_PERMISSIONS = arrayOf(
    Manifest.permission.ACCESS_FINE_LOCATION,
    Manifest.permission.ACCESS_COARSE_LOCATION
)

internal fun hasLocationPermission(context: Context): Boolean = LOCATION_PERMISSIONS.any {
    ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
}

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

/**
 * Recentre la caméra sur l'utilisateur : dernière position connue si elle est récente, sinon une
 * position demandée à l'instant (la dernière connue est souvent absente sur un vrai téléphone).
 */
internal fun recenterOnUser(context: Context, map: MapLibreMap?) {
    val m = map ?: return
    currentUserLocation(context) { loc ->
        m.animateCamera(
            CameraUpdateFactory.newCameraPosition(
                CameraPosition.Builder()
                    .target(LatLng(loc.latitude, loc.longitude))
                    .zoom(15.0)
                    .build()
            )
        )
    }
}

private const val RECENT_LOCATION_NANOS = 120_000_000_000L

@SuppressLint("MissingPermission")
private fun currentUserLocation(context: Context, onLocation: (Location) -> Unit) {
    if (!hasLocationPermission(context)) return
    val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
    val providers = lm.getProviders(true)
    val last = providers
        .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
        .maxByOrNull { it.elapsedRealtimeNanos }
    if (last != null && SystemClock.elapsedRealtimeNanos() - last.elapsedRealtimeNanos < RECENT_LOCATION_NANOS) {
        onLocation(last)
        return
    }
    val provider = listOfNotNull(
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) LocationManager.FUSED_PROVIDER else null,
        LocationManager.NETWORK_PROVIDER,
        LocationManager.GPS_PROVIDER
    ).firstOrNull { it in providers }
    if (provider == null) { last?.let(onLocation); return }
    val deliver: (Location?) -> Unit = { fresh -> (fresh ?: last)?.let(onLocation) }
    // Refus possible selon le fournisseur quand seule la position approximative est accordée.
    runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lm.getCurrentLocation(provider, null, context.mainExecutor) { deliver(it) }
        } else {
            @Suppress("DEPRECATION")
            lm.requestSingleUpdate(provider, { deliver(it) }, Looper.getMainLooper())
        }
    }.onFailure { last?.let(onLocation) }
}

/**
 * Action du bouton « Ma position » : recentre si la position est autorisée, sinon la demande,
 * puis allume le point bleu et recentre dès qu'elle est accordée.
 */
@Composable
internal fun rememberLocateUser(map: MapLibreMap?): () -> Unit {
    val context = LocalContext.current
    val currentMap by rememberUpdatedState(map)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        val m = currentMap ?: return@rememberLauncherForActivityResult
        if (!hasLocationPermission(context)) return@rememberLauncherForActivityResult
        m.style?.let { enableLocationComponent(context, m, it) }
        recenterOnUser(context, m)
    }
    return {
        if (hasLocationPermission(context)) recenterOnUser(context, currentMap)
        else launcher.launch(LOCATION_PERMISSIONS)
    }
}

// ── Contrôles ───────────────────────────────────────────────────────────────

/**
 * Bouton rond des contrôles carte (recentrage, satellite, filtres…) : deux couleurs seulement,
 * l'accent sur verre au repos, verre plein d'accent avec pictogramme blanc quand il est actif.
 */
@Composable
internal fun MapCircleFab(
    icon: ImageVector,
    contentDesc: String,
    active: Boolean = false,
    onClick: () -> Unit
) {
    SmallFloatingActionButton(
        onClick = onClick,
        shape = CircleShape,
        containerColor = if (active) Tokens.accent else MaterialTheme.colorScheme.surface.copy(alpha = 0.72f),
        contentColor = if (active) Color.White else Tokens.accent,
        modifier = Modifier.glass(CircleShape, alpha = 0f),
    ) {
        Icon(icon, contentDesc, modifier = Modifier.size(22.dp))
    }
}
