package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

@Serializable
data class Passage(
    val stopId: Int,
    val ligne: String,
    val direction: String,
    val delaipassage: String,
    val heurepassage: String,
    val type: String  // "T" théorique ou "R" temps réel
) {
    val id: String get() = "$stopId-$ligne-$heurepassage"
    val isRealTime: Boolean get() = type == "R"

    /** Format `HH:mm` (extrait de heurepassage `yyyy-MM-dd HH:mm:ss`). */
    val formattedTime: String get() {
        val parts = heurepassage.split(" ")
        if (parts.size >= 2) {
            val tp = parts[1].split(":")
            if (tp.size >= 2) return "${tp[0]}:${tp[1]}"
        }
        return heurepassage
    }
}

@Serializable
data class TransitStop(
    val id: Int,
    val nom: String,
    val commune: String,
    val adresse: String? = null,
    val latitude: Double,
    val longitude: Double,
    /** Format CSV brut: "C20:A,JD975:R,..." */
    val desserte: String,
    val pmr: Boolean,
    val passages: List<Passage> = emptyList(),
    val isLoadingPassages: Boolean = false,
    val passagesLoaded: Boolean = false
) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)

    /** Lignes uniques desservant cet arrêt. */
    val lines: List<String> by lazy {
        desserte.split(",")
            .mapNotNull { it.split(":").firstOrNull() }
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .distinct()
    }

    /** Directions desservies par cet arrêt. */
    val directions: List<String> by lazy {
        desserte.split(",")
            .mapNotNull {
                val parts = it.split(":")
                if (parts.size >= 2) parts[1].trim() else null
            }
            .distinct()
    }

    val nextPassage: Passage? get() = passages.firstOrNull()
    val hasPassages: Boolean get() = passages.isNotEmpty()
}

/** Plusieurs TransitStop fusionnés (même nom, distance < 30m). */
@Serializable
data class MergedStop(
    val id: String,
    val nom: String,
    val latitude: Double,
    val longitude: Double,
    val stops: List<TransitStop>,
    val directions: List<String>
) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)
    val allLines: List<String> by lazy { stops.flatMap { it.lines }.distinct() }
    val pmr: Boolean by lazy { stops.any { it.pmr } }
}
