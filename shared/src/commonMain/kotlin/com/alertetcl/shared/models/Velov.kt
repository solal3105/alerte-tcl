package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

/**
 * Station Vélo'v (données ouvertes du Grand Lyon, allégées par le relais sur `/velov`).
 * Les champs portent les noms du JSON du relais.
 */
@Serializable
data class VelovStation(
    val id: Int,
    /** Nom brut de l'exploitant, précédé du numéro de station (« 5045 - VALDO / RIVET »). */
    val name: String,
    val address: String = "",
    val lat: Double,
    val lng: Double,
    /** Vélos disponibles, dont électriques et mécaniques. */
    val bikes: Int,
    val ebikes: Int = 0,
    val mbikes: Int = 0,
    /** Places libres pour rendre un vélo, et capacité totale. */
    val stands: Int,
    val capacity: Int = 0,
    val open: Boolean = true,
    /** Dernière mise à jour transmise par l'exploitant (epoch, secondes). */
    val updated: Long? = null
) {
    val coordinate: LatLng get() = LatLng(lat, lng)

    /** « Valdo / Rivet » : sans le numéro, en minuscules avec majuscules initiales. */
    val displayName: String get() {
        val raw = name.substringAfter(" - ", name).trim()
        return raw.lowercase().split(" ").joinToString(" ") { word ->
            word.split("-").joinToString("-") { part -> part.replaceFirstChar { it.uppercase() } }
        }
    }

    /** Vert dès 3 vélos, orange à 1 ou 2, rouge sans vélo, gris quand la station est fermée. */
    val availability: AvailabilityColor get() = when {
        !open -> AvailabilityColor.GRAY
        bikes <= 0 -> AvailabilityColor.RED
        bikes <= 2 -> AvailabilityColor.ORANGE
        else -> AvailabilityColor.GREEN
    }

    val bikesText: String get() = when {
        !open -> "Station fermée"
        bikes <= 0 -> "Aucun vélo disponible"
        else -> {
            val detail = if (ebikes > 0 || mbikes > 0) ", dont $ebikes électrique${if (ebikes > 1) "s" else ""} et $mbikes mécanique${if (mbikes > 1) "s" else ""}" else ""
            "$bikes vélo${if (bikes > 1) "s" else ""} disponible${if (bikes > 1) "s" else ""}$detail"
        }
    }

    val standsText: String get() = when {
        !open -> ""
        stands <= 0 -> "Aucune place libre pour rendre un vélo"
        else -> "$stands place${if (stands > 1) "s" else ""} libre${if (stands > 1) "s" else ""} pour rendre un vélo"
    }

    /** « Mis à jour il y a 3 min », ou vide sans horodatage. */
    fun updatedText(nowEpochMs: Long): String {
        val at = updated ?: return ""
        val age = (nowEpochMs / 1000 - at).coerceAtLeast(0)
        return "Mis à jour il y a ${Vehicle.formattedAge(age)}"
    }
}

@Serializable
data class VelovResponse(val stations: List<VelovStation> = emptyList())
