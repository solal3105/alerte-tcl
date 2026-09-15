package com.alertetcl.shared.models

/**
 * Filtre temporaire de la carte : ne montrer que les véhicules d'une ligne dans un sens,
 * choisi depuis la fiche d'un arrêt (« Voir ces bus sur la carte »). Jamais persisté.
 */
data class StopLineFocus(
    val line: String,
    /** "A" / "R", ou null si le sens n'a pas pu être déterminé (la ligne entière est montrée). */
    val direction: String?,
    val destination: String,
    val stopName: String,
    val latitude: Double,
    val longitude: Double
) {
    fun matches(vehicle: Vehicle): Boolean = matches(vehicle.lineName, vehicle.direction)

    /** Même règle sur les champs bruts, pour les modèles de véhicule qui ne viennent pas encore du module partagé. */
    fun matches(lineName: String, vehicleDirection: String): Boolean =
        lineName.equals(line, ignoreCase = true) &&
            (direction == null || vehicleDirection.isEmpty() || vehicleDirection == direction)
}
