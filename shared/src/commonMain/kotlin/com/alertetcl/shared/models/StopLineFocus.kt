package com.alertetcl.shared.models

/**
 * Filtre temporaire de la carte : ne montrer que les véhicules d'une ligne, dans un sens quand il
 * vient de la fiche d'un arrêt (« Voir ces bus sur la carte »), dans les deux sens quand il vient
 * du clic sur un véhicule. Jamais persisté ; le bandeau « Tout afficher » le retire.
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
    /** Vrai quand le filtre vient de la fiche d'un arrêt (sinon, du clic sur un véhicule). */
    val fromStop: Boolean get() = stopName.isNotEmpty()

    val bannerTitle: String get() = if (fromStop) "Vers $destination" else "Ligne $line"

    fun bannerSubtitle(vehicleCount: Int): String {
        val count = when (vehicleCount) {
            0 -> "Aucun véhicule en circulation pour l'instant"
            1 -> "1 véhicule affiché"
            else -> "$vehicleCount véhicules affichés"
        }
        return if (fromStop) "$count, depuis l'arrêt $stopName" else count
    }

    fun matches(vehicle: Vehicle): Boolean = matches(vehicle.lineName, vehicle.direction)

    /** Même règle sur les champs bruts, pour les modèles de véhicule qui ne viennent pas encore du module partagé. */
    fun matches(lineName: String, vehicleDirection: String): Boolean =
        lineName.equals(line, ignoreCase = true) &&
            (direction == null || vehicleDirection.isEmpty() || vehicleDirection == direction)

    companion object {
        /** Filtre sur toute la ligne d'un véhicule touché sur la carte. */
        fun forVehicle(vehicle: Vehicle): StopLineFocus = StopLineFocus(
            line = vehicle.lineName, direction = null, destination = vehicle.destination,
            stopName = "", latitude = vehicle.latitude, longitude = vehicle.longitude
        )
    }
}
