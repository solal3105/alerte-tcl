package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

/**
 * Tracé d'une ligne de bus (généralement segments multiples).
 * Les coordonnées sont au format GeoJSON [lon, lat] — converties via [points].
 */
@Serializable
data class BusLine(
    val id: String,
    val name: String,
    /** Suite de [lon, lat]. */
    val coordinates: List<List<Double>>
) {
    val points: List<LatLng> get() = coordinates.mapNotNull { LatLng.fromGeoJSON(it) }
}

/**
 * Tracé d'une ligne métro/funi/tram.
 */
@Serializable
data class TransitLine(
    val id: String,
    val name: String,
    val coordinates: List<List<Double>>,
    val familyTransport: String
) {
    val points: List<LatLng> get() = coordinates.mapNotNull { LatLng.fromGeoJSON(it) }

    /** Couleur du tracé en hex `#RRGGBB`. */
    val strokeColorHex: String get() = LineColors.routeStrokeHex(name)
}
