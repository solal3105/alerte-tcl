package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

@Serializable
enum class VehicleType(val displayName: String, val iconKey: String, val sortOrder: Int) {
    METRO("Métro", "metro", 0),
    FUNICULAR("Funiculaire", "funicular", 1),
    TRAM("Tramway", "tram", 2),
    TROLLEY("Trolleybus", "trolley", 3),
    BUS("Bus", "bus", 4);

    /** Couleur dominante sur la carte (hex `#RRGGBB`). */
    val clusterColorHex: String get() = when (this) {
        METRO     -> "#EE3898"
        TRAM      -> "#8C368C"
        BUS       -> "#6E6E73"
        TROLLEY   -> "#DAA520"
        FUNICULAR -> "#8BC752"
    }
}

@Serializable
data class StopInfo(
    val id: String,
    val stopRef: String,
    val stopName: String? = null,
    val aimedArrivalTimeEpoch: Long? = null,
    val aimedDepartureTimeEpoch: Long? = null,
    val distanceFromStop: Int? = null,
    val order: Int? = null
)

@Serializable
data class Vehicle(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val bearing: Double,
    val lineRef: String,
    val lineName: String,
    val vehicleType: VehicleType,
    val destination: String,
    val delay: Int,
    val status: String? = null,
    val recordedAtEpoch: Long? = null,
    val validUntilEpoch: Long? = null,
    val nextStop: StopInfo? = null
) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)

    val delayFormatted: String get() = when {
        delay == 0  -> "À l'heure"
        delay > 0   -> {
            val minutes = delay / 60
            if (minutes > 0) "+$minutes min" else "+$delay sec"
        }
        else -> {
            val abs = -delay
            val minutes = abs / 60
            if (minutes > 0) "-$minutes min" else "$delay sec"
        }
    }

    val isDelayed: Boolean get() = delay > 60
    val isEarly:   Boolean get() = delay < -60
}
