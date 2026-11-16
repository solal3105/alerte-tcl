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

    /** L'état du moment en une ligne : « 5 classiques · 9 électriques · 4 places », ou « Station fermée ». */
    val stateText: String get() =
        if (!open) "Station fermée"
        else VelovFilter.detailed.joinToString(" · ") { VelovTexts.count(shownCount(it), it) }
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

        /**
         * Le détail de l'état du moment, dans l'ordre de la fiche : classiques, électriques, places.
         * Chaque plateforme y lit `shownCount` et `VelovTexts.unit` pour chaque case.
         */
        val detailed: List<VelovFilter> = listOf(MECHANICAL, ELECTRIC, STANDS)

        /** Relit une préférence enregistrée, et revient à « Tous » si elle est absente ou inconnue. */
        fun fromName(name: String?): VelovFilter = ordered.firstOrNull { it.name == name } ?: ALL
    }
}

@Serializable
data class VelovResponse(val stations: List<VelovStation> = emptyList())
