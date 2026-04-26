package com.alertetcl.shared.geo

import kotlin.math.cos
import kotlin.math.sqrt

/**
 * Coordonnée géographique. Equivalent multiplatforme de CLLocationCoordinate2D.
 */
data class LatLng(
    val latitude: Double,
    val longitude: Double
) {
    val isValid: Boolean
        get() = latitude.isFinite() && longitude.isFinite() &&
                latitude in -90.0..90.0 && longitude in -180.0..180.0 &&
                latitude != 0.0 && longitude != 0.0

    companion object {
        /** Parse une coordonnée GeoJSON [lon, lat] ou [lon, lat, alt]. */
        fun fromGeoJSON(coordinates: List<Double>): LatLng? {
            if (coordinates.size < 2) return null
            val lon = coordinates[0]
            val lat = coordinates[1]
            if (!lat.isFinite() || !lon.isFinite()) return null
            if (lat !in -90.0..90.0 || lon !in -180.0..180.0) return null
            return LatLng(lat, lon)
        }
    }
}

/**
 * Distance approximative en mètres entre deux coordonnées proches (< quelques km).
 * Utilise la projection plate. Précis < 1% à Lyon.
 */
fun fastDistance2D(a: LatLng, b: LatLng): Double {
    val dLat = (b.latitude - a.latitude) * 111_320.0
    val dLon = (b.longitude - a.longitude) * 111_320.0 * cos(a.latitude * kotlin.math.PI / 180.0)
    return sqrt(dLat * dLat + dLon * dLon)
}

/** Distance au carré en mètres — évite sqrt pour comparaisons. */
fun distanceSquaredMeters(a: LatLng, b: LatLng): Double {
    val dLat = (b.latitude - a.latitude) * 111_320.0
    val dLon = (b.longitude - a.longitude) * 78_710.0
    return dLat * dLat + dLon * dLon
}

/** Région rectangulaire (équivalent MKCoordinateRegion). */
data class GeoRegion(
    val center: LatLng,
    val latitudeDelta: Double,
    val longitudeDelta: Double
) {
    val minLatitude  get() = center.latitude  - latitudeDelta
    val maxLatitude  get() = center.latitude  + latitudeDelta
    val minLongitude get() = center.longitude - longitudeDelta
    val maxLongitude get() = center.longitude + longitudeDelta

    fun contains(point: LatLng): Boolean =
        point.latitude  in minLatitude..maxLatitude &&
        point.longitude in minLongitude..maxLongitude
}
