package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import kotlinx.serialization.Serializable

@Serializable
enum class TravauxNatureChantier(val displayName: String, val iconKey: String, val colorHex: String) {
    TRANSPORTS_COMMUN("Transports en commun", "tram", "#A855F7"),
    CYCLAB("Aménagements cyclables", "bike", "#22C55E"),
    ESPACE_PUBLIC("Espace public", "building", "#3B82F6"),
    CARREFOUR("Carrefours", "branch", "#F97316"),
    ASSAINISSEMENT("Assainissement", "drop", "#854D0E"),
    AUTRE("Autre", "hammer", "#6B7280");

    companion object {
        fun detect(natureChantier: String?): TravauxNatureChantier {
            val n = natureChantier?.lowercase() ?: return AUTRE
            return when {
                "transport" in n || "bus" in n || "tram" in n -> TRANSPORTS_COMMUN
                "cyclable" in n || "vélo" in n || "velo" in n || "edp" in n -> CYCLAB
                "espace public" in n || "aménagement" in n -> ESPACE_PUBLIC
                "carrefour" in n -> CARREFOUR
                "assainissement" in n -> ASSAINISSEMENT
                else -> AUTRE
            }
        }
    }
}

@Serializable
enum class TravauxType(val displayName: String, val iconKey: String) {
    TRAMWAY("Tramway", "tram"),
    METRO("Métro", "metro"),
    VOIRIE("Voirie", "road"),
    EAU("Eau", "drop"),
    GAZ("Gaz", "flame"),
    ELECTRICITE("Électricité", "bolt"),
    ASSAINISSEMENT("Assainissement", "pipe"),
    TELECOM("Télécom", "antenna"),
    CHAUFFAGE("Chauffage", "thermometer"),
    PISTE_CYCLABLE("Piste cyclable", "bike"),
    AUTRE("Autre", "hammer");

    companion object {
        fun detect(nomChantier: String): TravauxType {
            val n = nomChantier.lowercase()
            return when {
                "tramway" in n || "tram" in n || "bus" in n -> TRAMWAY
                "métro" in n || "metro" in n -> METRO
                "piste cyclable" in n || "vélo" in n || "velo" in n || "cyclable" in n -> PISTE_CYCLABLE
                "eau" in n || "aep" in n -> EAU
                "gaz" in n -> GAZ
                "électr" in n || "electr" in n || "éclairage" in n || "eclairage" in n -> ELECTRICITE
                "assainissement" in n || "égout" in n || "egout" in n -> ASSAINISSEMENT
                "télécom" in n || "telecom" in n || "fibre" in n || "réseau" in n -> TELECOM
                "chauffage" in n || "thermique" in n -> CHAUFFAGE
                "voirie" in n || "chaussée" in n || "chaussee" in n || "revêtement" in n -> VOIRIE
                else -> AUTRE
            }
        }
    }
}

@Serializable
enum class TravauxAvancement(val raw: String, val displayName: String, val iconKey: String) {
    EN_COURS("Chantier en cours", "En cours", "hammer"),
    PREVU("Chantier prévu", "Prévu", "calendar"),
    TERMINE("Chantier terminé", "Terminé", "check"),
    INCONNU("Inconnu", "Inconnu", "question");

    companion object {
        fun parse(raw: String?): TravauxAvancement =
            entries.firstOrNull { it.raw == raw } ?: INCONNU
    }
}

@Serializable
enum class TravauxImportance(val code: Int, val displayName: String) {
    TRES_PERTURBANT(1, "Très perturbant"),
    PERTURBANT(2, "Perturbant"),
    PEU_PERTURBANT(3, "Peu perturbant"),
    INCONNU(0, "Non défini");

    companion object {
        fun parse(code: Int?): TravauxImportance =
            entries.firstOrNull { it.code == code } ?: INCONNU
    }
}

@Serializable
enum class TravauxPerturbation(val raw: String, val iconKey: String) {
    INTERDITE("Circulation interdite", "xmark"),
    REDUITE("Circulation réduite", "arrows"),
    ALTERNEE("Circulation alternée", "swap"),
    GENE("Gêne ponctuelle", "warning"),
    AUTRE("Autre", "question");

    companion object {
        fun parse(raw: String?): TravauxPerturbation =
            entries.firstOrNull { it.raw == raw } ?: AUTRE
    }
}

@Serializable
data class Travaux(
    val id: String,
    val nom: String,
    val nomChantier: String,
    val commune: String,
    val codeInsee: String,
    val precisionLocalisation: String? = null,
    val debutEpoch: Long? = null,
    val finEpoch: Long? = null,
    val description: String? = null,
    val avancement: TravauxAvancement,
    val importance: TravauxImportance,
    val typePerturbation: TravauxPerturbation,
    val intervenant: String,
    /** Polygones extérieurs uniquement (chaque sous-liste = un anneau extérieur). */
    val polygons: List<List<LatLng>>,
    val centroid: LatLng,
    val type: TravauxType,
    val natureChantier: TravauxNatureChantier
) {
    fun isActive(nowEpoch: Long): Boolean {
        val end = finEpoch ?: return true
        return end >= nowEpoch
    }

    /** Pourcentage 0..100 de réalisation. */
    fun completionPercentage(nowEpoch: Long): Double {
        val start = debutEpoch
        val end = finEpoch
        if (start == null || end == null) {
            return when (avancement) {
                TravauxAvancement.TERMINE -> 100.0
                TravauxAvancement.EN_COURS -> 50.0
                else -> 0.0
            }
        }
        if (nowEpoch < start) return 0.0
        if (nowEpoch >= end) return 100.0
        val total = (end - start).toDouble()
        if (total <= 0) return 0.0
        return ((nowEpoch - start).toDouble() / total) * 100.0
    }
}
