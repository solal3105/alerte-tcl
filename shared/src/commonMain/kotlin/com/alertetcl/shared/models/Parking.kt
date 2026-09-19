package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

/**
 * Ce que l'onglet Stationnement peut montrer. L'ordre des valeurs est celui des tuiles de l'écran
 * d'accueil ; `title` et `subtitle` sont les textes affichés, identiques sur iOS et Android.
 * `iconKey` entre dans l'identifiant des parkings, ne pas le changer.
 */
@Serializable
enum class ParkingType(val title: String, val subtitle: String, val iconKey: String) {
    CAR("Parkings voiture", "Places libres en direct et parcs relais TCL", "car"),
    /** Stations Vélo'v en libre-service : pas un jeu GeoServer, servies par `VelovService`. */
    VELOV("Stations Vélo'v", "Vélos et places disponibles en direct", "velov"),
    BIKE("Arceaux vélos", "Où attacher votre vélo dans la rue", "bike"),
    MOTORIZED_2W("Places deux-roues motorisés", "Emplacements réservés aux motos et scooters", "moto");
}

@Serializable
enum class ParkingState(val raw: String, val displayName: String) {
    OUVERT("ouvert", "Ouvert"),
    FERME("ferme", "Fermé"),
    COMPLET("complet", "Complet"),
    INCONNU("inconnu", "Inconnu");

    companion object {
        fun parse(raw: String?): ParkingState =
            entries.firstOrNull { it.raw.equals(raw, ignoreCase = true) } ?: INCONNU
    }
}

/**
 * Couleur de disponibilité (gray / green / orange / red).
 * Interprétation par l'UI native : "gray" → systemGray, etc.
 */
enum class AvailabilityColor { GRAY, GREEN, ORANGE, RED }

@Serializable
data class Parking(
    val id: String,
    val gid: Int,
    val nom: String,
    val gestionnaire: String,
    val adresse: String,
    val latitude: Double,
    val longitude: Double,
    val capaciteTotale: Int,
    val placesDisponibles: Int,
    val etat: ParkingState,
    val lastUpdateEpoch: Long? = null,
    val parkingType: ParkingType,

    // Parc Relais
    val isParcRelais: Boolean = false,
    val horaires: String? = null,
    val surveille: Boolean? = null,
    val hasRealtimeData: Boolean = true,

    val url: String? = null,
    val hauteurMax: String? = null,
    val nbPmr: Int? = null,
    val nbVoituresElectriques: Int? = null,
    val nbVelo: Int? = null,
    val nb2Rm: Int? = null,
    val nbAutopartage: Int? = null,

    val tarif1h: Double? = null,
    val tarif2h: Double? = null,
    val tarif3h: Double? = null,
    val tarif4h: Double? = null,
    val tarif24h: Double? = null,
    val aboResident: Double? = null,
    val aboNonResident: Double? = null,
    val gratuit: Boolean = false
) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)

    val tauxOccupation: Double get() {
        if (!hasRealtimeData || capaciteTotale <= 0) return 0.0
        return (capaciteTotale - placesDisponibles).toDouble() / capaciteTotale.toDouble()
    }

    val availabilityColor: AvailabilityColor get() {
        if (!hasRealtimeData) return AvailabilityColor.GRAY
        if (!isParcRelais && etat != ParkingState.OUVERT) return AvailabilityColor.GRAY
        return when {
            tauxOccupation < 0.5 -> AvailabilityColor.GREEN
            tauxOccupation < 0.8 -> AvailabilityColor.ORANGE
            else                 -> AvailabilityColor.RED
        }
    }

    val isFull: Boolean get() {
        if (!hasRealtimeData) return false
        return placesDisponibles == 0 || etat == ParkingState.COMPLET
    }
}
