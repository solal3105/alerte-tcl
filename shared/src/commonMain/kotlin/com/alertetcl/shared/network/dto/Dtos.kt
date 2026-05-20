package com.alertetcl.shared.network.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ─── Alerts ──────────────────────────────────────────────────────────────────

@Serializable
data class AlertsApiResponse(val values: List<AlertDto> = emptyList())

@Serializable
data class AlertDto(
    val n: Int? = null,
    val type: String? = null,
    val cause: String? = null,
    val debut: String? = null,
    val fin: String? = null,
    val mode: String? = null,
    @SerialName("ligne_com") val ligneCom: String? = null,
    @SerialName("ligne_cli") val ligneCli: String? = null,
    val titre: String? = null,
    val message: String? = null,
    @SerialName("niveauseverite") val niveauSeverite: Int? = null
)

// ─── Stops ───────────────────────────────────────────────────────────────────

@Serializable
data class StopsResponse(val features: List<StopFeature> = emptyList())

@Serializable
data class StopFeature(
    val geometry: PointGeometry,
    val properties: StopProperties
)

@Serializable
data class StopProperties(
    val id: Int,
    val nom: String,
    val commune: String? = null,
    val adresse: String? = null,
    val desserte: String? = null,
    val pmr: Boolean? = null
)

@Serializable
data class PointGeometry(
    val type: String? = null,
    val coordinates: List<Double> = emptyList()
)

@Serializable
data class PassagesResponse(val values: List<PassageDto> = emptyList())

@Serializable
data class PassageDto(
    val id: Int,
    val ligne: String,
    val direction: String,
    val delaipassage: String,
    val heurepassage: String,
    val type: String
)

// ─── Bus / Transit lines ─────────────────────────────────────────────────────

@Serializable
data class BusLineResponse(val features: List<BusLineFeature> = emptyList())

@Serializable
data class BusLineFeature(
    val id: String,
    val geometry: MultiLineGeometry,
    val properties: LineProperties
)

@Serializable
data class TransitLineResponse(val features: List<TransitLineFeature> = emptyList())

@Serializable
data class TransitLineFeature(
    val id: String,
    val geometry: MultiLineGeometry,
    val properties: LineProperties
)

@Serializable
data class LineProperties(
    val ligne: String? = null,
    @SerialName("famille_transport") val familleTransport: String? = null,
    val sens: String? = null,
    @SerialName("nom_destination") val nomDestination: String? = null
)

@Serializable
data class MultiLineGeometry(
    val type: String? = null,
    val coordinates: List<List<List<Double>>> = emptyList()
)

// ─── Parking ─────────────────────────────────────────────────────────────────

@Serializable
data class ParkingResponse(val features: List<ParkingFeature> = emptyList())

@Serializable
data class ParkingFeature(
    val id: String? = null,
    val geometry: PointGeometry? = null,
    val properties: ParkingProperties
)

@Serializable
data class ParkingProperties(
    val gid: Int? = null,
    val nom: String? = null,
    val adresse: String? = null,
    val gestionnaire: String? = null,
    val capacite: Int? = null,
    val nb_place_dispo: Int? = null,
    val nb_places: Int? = null,
    val places_disponibles: Int? = null,
    val etat: String? = null,
    val date_maj: String? = null,
    val url: String? = null,
    val hauteur_max: String? = null,
    val nb_pmr: Int? = null,
    val nb_voi_elec: Int? = null,
    val nb_velo: Int? = null,
    val nb_2rm: Int? = null,
    val nb_autopartage: Int? = null,
    val tarif_1h: Double? = null,
    val tarif_2h: Double? = null,
    val tarif_3h: Double? = null,
    val tarif_4h: Double? = null,
    val tarif_24h: Double? = null,
    val abo_resident: Double? = null,
    val abo_non_resident: Double? = null,
    val nbarceaux: Int? = null,
    val longueur: Double? = null
)

// ─── Travaux ─────────────────────────────────────────────────────────────────

@Serializable
data class TravauxResponse(val features: List<TravauxFeature> = emptyList())

@Serializable
data class TravauxFeature(
    val id: String,
    val geometry: PolygonGeometry,
    val properties: TravauxProperties
)

@Serializable
data class PolygonGeometry(
    val type: String? = null,
    /** MultiPolygon: list of polygons; each polygon is a list of rings; each ring is a list of [lon,lat]. */
    val coordinates: List<List<List<List<Double>>>> = emptyList()
)

@Serializable
data class TravauxProperties(
    @SerialName("nature_chantier") val natureChantier: String? = null,
    @SerialName("nature_travaux")  val natureTravaux: String? = null,
    @SerialName("date_debut")      val dateDebut: String? = null,
    @SerialName("date_fin")        val dateFin: String? = null,
    val etat: String? = null,
    @SerialName("mesures_police")  val mesuresPolice: String? = null,
    val intervenant: String? = null,
    val adresse: String? = null,
    val commune: String? = null,
    @SerialName("code_insee")      val codeInsee: Int? = null,
    val gid: Int? = null,

    val nom: String? = null,
    val nomchantier: String? = null,
    val commune1: String? = null,
    val insee: String? = null,
    val precisionlocalisation: String? = null,
    val debutchantier: String? = null,
    val finchantier: String? = null,
    val descripchantierinternet: String? = null,
    val avancement: String? = null,
    val importance: String? = null,
    val typeperturbation: String? = null,
    val codeimportance: Int? = null
)

// ─── SIRI Lite (vehicles) ────────────────────────────────────────────────────

@Serializable
data class SIRIResponse(@SerialName("Siri") val Siri: SIRIRoot)

@Serializable
data class SIRIRoot(@SerialName("ServiceDelivery") val ServiceDelivery: ServiceDelivery)

@Serializable
data class ServiceDelivery(
    @SerialName("VehicleMonitoringDelivery")
    val VehicleMonitoringDelivery: List<VehicleMonitoringDelivery>? = null
)

@Serializable
data class VehicleMonitoringDelivery(
    @SerialName("VehicleActivity")
    val VehicleActivity: List<VehicleActivity>? = null,
    @SerialName("MoreData")
    val MoreData: Boolean? = null
)

@Serializable
data class VehicleActivity(
    @SerialName("VehicleMonitoringRef") val VehicleMonitoringRef: SiriValue? = null,
    @SerialName("RecordedAtTime") val RecordedAtTime: String? = null,
    @SerialName("ValidUntilTime") val ValidUntilTime: String? = null,
    @SerialName("MonitoredVehicleJourney") val MonitoredVehicleJourney: MonitoredVehicleJourney? = null
)

@Serializable
data class MonitoredVehicleJourney(
    @SerialName("LineRef") val LineRef: SiriValue? = null,
    @SerialName("DirectionRef") val DirectionRef: SiriValue? = null,
    @SerialName("VehicleRef") val VehicleRef: SiriValue? = null,
    @SerialName("DestinationRef") val DestinationRef: SiriValue? = null,
    @SerialName("VehicleLocation") val VehicleLocation: VehicleLocation? = null,
    @SerialName("Bearing") val Bearing: Double? = null,
    @SerialName("Delay") val Delay: String? = null,
    @SerialName("VehicleStatus") val VehicleStatus: String? = null,
    @SerialName("MonitoredCall") val MonitoredCall: MonitoredCallDto? = null
)

@Serializable
data class SiriValue(val value: String? = null)

@Serializable
data class VehicleLocation(
    @SerialName("Latitude") val Latitude: Double? = null,
    @SerialName("Longitude") val Longitude: Double? = null
)

@Serializable
data class MonitoredCallDto(
    @SerialName("StopPointRef") val StopPointRef: SiriValue? = null,
    @SerialName("AimedArrivalTime") val AimedArrivalTime: String? = null,
    @SerialName("AimedDepartureTime") val AimedDepartureTime: String? = null,
    @SerialName("DepartureStatus") val DepartureStatus: String? = null,
    @SerialName("DistanceFromStop") val DistanceFromStop: Int? = null,
    @SerialName("Order") val Order: Int? = null
)

// ─── Parc Relais ─────────────────────────────────────────────────────────────

@Serializable
data class ParcRelaisStaticResponse(val features: List<ParcRelaisStaticFeature> = emptyList())

@Serializable
data class ParcRelaisStaticFeature(
    val geometry: ParcRelaisGeometry,
    val properties: ParcRelaisStaticProperties
)

@Serializable
data class ParcRelaisGeometry(
    val type: String? = null,
    /** Format MultiPoint: list of [lon, lat]. */
    val coordinates: List<List<Double>> = emptyList()
)

@Serializable
data class ParcRelaisStaticProperties(
    val id: String,
    val nom: String,
    val capacite: Int? = null,
    @SerialName("place_handi") val placeHandi: Int? = null,
    val horaires: String? = null,
    @SerialName("p_surv") val pSurv: Boolean? = null
)

@Serializable
data class ParcRelaisRealtimeResponse(val features: List<ParcRelaisRealtimeFeature> = emptyList())

@Serializable
data class ParcRelaisRealtimeFeature(val properties: ParcRelaisRealtimeProperties)

@Serializable
data class ParcRelaisRealtimeProperties(
    val id: String,
    @SerialName("nb_tot_place_dispo") val nbTotPlaceDispo: Int? = null
)
