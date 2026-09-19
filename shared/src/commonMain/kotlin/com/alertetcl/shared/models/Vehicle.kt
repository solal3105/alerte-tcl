package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

@Serializable
enum class VehicleType(val displayName: String, val iconKey: String, val sortOrder: Int) {
    METRO("Métro", "metro", 0),
    FUNICULAR("Funiculaire", "funicular", 1),
    TRAM("Tramway", "tram", 2),
    TROLLEY("Trolleybus", "trolley", 3),
    NAVIGONE("Navigo'ne", "navigone", 4),
    BUS("Bus", "bus", 5);
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
) {
    /** Identifiant TCL de l'arrêt (« ActIV:StopArea:SP:11518:SYTRAL » → 11518), commun au GeoServer et aux fiches horaires. */
    val numericId: Int? get() = stopRef.split(":").getOrNull(3)?.toIntOrNull() ?: stopRef.toIntOrNull()
}

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
    /** Sens SIRI normalisé : "A" aller, "R" retour, "" inconnu (cf. DirectionMatching). */
    val direction: String = "",
    val delay: Int,
    val status: String? = null,
    val recordedAtEpoch: Long? = null,
    val validUntilEpoch: Long? = null,
    val nextStop: StopInfo? = null
) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)

    /** Numéro de parc extrait du VehicleRef SIRI (ex. "ActIV:Vehicle:Bus:1512:LOC" → "1512"). */
    val fleetNumber: String? get() = id.split(":").getOrNull(3)?.takeIf { it.isNotEmpty() }

    /** Ponctualité : le chiffre, ce qu'il veut dire, et la phrase entière (cf. [VehicleTexts]). */
    val delayAmount: String get() = VehicleTexts.punctualityAmount(delay)
    val delayCaption: String get() = VehicleTexts.punctualityCaption(delay)
    val delayText: String get() = VehicleTexts.punctuality(delay)

    val isDelayed: Boolean get() = VehicleTexts.isDelayed(delay)
    val isEarly:   Boolean get() = VehicleTexts.isEarly(delay)

    /**
     * Arrivée au prochain arrêt (epoch, secondes) : son horaire prévu corrigé du retard constaté,
     * comme l'estimation de « Où est mon bus ». Null quand TCL ne donne pas d'horaire pour cet arrêt.
     */
    val nextStopArrivalEpoch: Long? get() = nextStop?.let { stop ->
        (stop.aimedArrivalTimeEpoch ?: stop.aimedDepartureTimeEpoch)?.plus(delay)
    }

    /** Légende de cette heure : « arrivée à Bellecour ». Null sans nom d'arrêt. */
    val nextStopArrivalCaption: String? get() = nextStop?.stopName?.let { VehicleTexts.arrivalCaption(it) }

    /** Âge de la dernière position transmise par TCL (RecordedAtTime SIRI), en secondes. */
    fun positionAgeSeconds(nowEpochMs: Long): Long? =
        recordedAtEpoch?.let { (nowEpochMs / 1000 - it).coerceAtLeast(0) }

    /**
     * Fraîcheur de la position, pour l'affichage (couleur de l'étiquette et de la fiche).
     * Le flux SIRI TCL republie chaque véhicule toutes les ~15-60 s ; passé
     * [HIDE_AFTER_SECONDS] sans nouvelle position, elle est obsolète : le véhicule
     * quitte la carte et sa fiche, si elle est ouverte, le signale.
     */
    fun positionFreshness(nowEpochMs: Long): PositionFreshness {
        val age = positionAgeSeconds(nowEpochMs) ?: return PositionFreshness.FRESH
        return when {
            age < 45                 -> PositionFreshness.FRESH
            age < HIDE_AFTER_SECONDS -> PositionFreshness.AGING
            else                     -> PositionFreshness.STALE
        }
    }

    /** False dès que la position est obsolète : le véhicule n'est plus dessiné sur la carte. */
    fun isShownOnMap(nowEpochMs: Long): Boolean = positionFreshness(nowEpochMs) != PositionFreshness.STALE

    companion object {
        /** Délai sans nouvelle position transmise par TCL au-delà duquel un véhicule disparaît de la carte. */
        const val HIDE_AFTER_SECONDS = 90L

        /** Formate un âge en texte court ("12 s", "1 min 30", "4 min"). */
        fun formattedAge(seconds: Long): String {
            if (seconds < 60) return "$seconds s"
            val m = seconds / 60
            val r = seconds % 60
            if (m >= 5 || r == 0L) return "$m min"
            return "$m min ${r.toString().padStart(2, '0')}"
        }
    }
}

enum class PositionFreshness {
    FRESH, AGING, STALE;

    /** Couleur d'état associée (jetons partagés, variantes claire et sombre). */
    val color: com.alertetcl.shared.design.ThemedColor get() = when (this) {
        FRESH -> com.alertetcl.shared.design.AppColors.fresh
        AGING -> com.alertetcl.shared.design.AppColors.aging
        STALE -> com.alertetcl.shared.design.AppColors.stale
    }
}
