package com.alertetcl.shared.util

import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.geo.LatLng

/**
 * Filtrage côté client de gros nuages d'items géolocalisés.
 * Equivalent du ViewportFilter Swift.
 */
object ViewportFilter {
    fun <T> filter(items: List<T>, region: GeoRegion, latitudeOf: (T) -> Double, longitudeOf: (T) -> Double): List<T> =
        items.filter { item ->
            val lat = latitudeOf(item)
            val lon = longitudeOf(item)
            lat in region.minLatitude..region.maxLatitude &&
            lon in region.minLongitude..region.maxLongitude
        }

    fun <T> filterByCoordinate(items: List<T>, region: GeoRegion, coord: (T) -> LatLng): List<T> =
        filter(items, region, { coord(it).latitude }, { coord(it).longitude })
}

/** Easing utilisé pour les animations de véhicules (quadratic ease-out). */
fun easeOutQuad(t: Double): Double {
    val clamped = t.coerceIn(0.0, 1.0)
    return clamped * (2.0 - clamped)
}
