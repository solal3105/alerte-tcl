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

    /** Vélos classiques, déduits du total quand l'exploitant ne détaille pas la motorisation. */
    val mechanicalBikes: Int get() = if (mbikes > 0) mbikes else (bikes - ebikes).coerceAtLeast(0)

    /** Ce que la station affiche sur la carte selon le filtre choisi. */
    fun shownCount(filter: VelovFilter): Int = when (filter) {
        VelovFilter.ALL -> bikes
        VelovFilter.MECHANICAL -> mechanicalBikes
        VelovFilter.ELECTRIC -> ebikes
        VelovFilter.STANDS -> stands
    }

    /** Vert dès 3 unités comptées, orange à 1 ou 2, rouge à zéro, gris quand la station est fermée. */
    fun availabilityFor(filter: VelovFilter): AvailabilityColor {
        val count = shownCount(filter)
        return when {
            !open -> AvailabilityColor.GRAY
            count <= 0 -> AvailabilityColor.RED
            count <= 2 -> AvailabilityColor.ORANGE
            else -> AvailabilityColor.GREEN
        }
    }

    val availability: AvailabilityColor get() = availabilityFor(VelovFilter.ALL)

    /** Le total, le détail par motorisation étant déjà donné par les compteurs de la fiche. */
    val bikesText: String get() = when {
        !open -> "Station fermée"
        bikes <= 0 -> "Aucun vélo disponible"
        else -> "$bikes vélo${if (bikes > 1) "s" else ""} disponible${if (bikes > 1) "s" else ""}"
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

/**
 * Ce que la carte compte sur chaque station Vélo'v. Le choix est gardé d'une ouverture à l'autre et
 * change à la fois le nombre affiché sur le marqueur et sa couleur de disponibilité.
 */
enum class VelovFilter(val title: String, val caption: String) {
    ALL("Tous", "Tous les vélos disponibles, électriques comme classiques"),
    MECHANICAL("Classiques", "Seulement les vélos sans assistance électrique"),
    ELECTRIC("Électriques", "Seulement les vélos à assistance électrique"),
    STANDS("Places", "Les places libres pour rendre un vélo");

    companion object {
        /** Ordre de la barre de filtres, partagé par iOS et Android. */
        val ordered: List<VelovFilter> = listOf(ALL, MECHANICAL, ELECTRIC, STANDS)

        /** Relit une préférence enregistrée, et revient à « Tous » si elle est absente ou inconnue. */
        fun fromName(name: String?): VelovFilter = ordered.firstOrNull { it.name == name } ?: ALL
    }
}

@Serializable
data class VelovResponse(val stations: List<VelovStation> = emptyList())
