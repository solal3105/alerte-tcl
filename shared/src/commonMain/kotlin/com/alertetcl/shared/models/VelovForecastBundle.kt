package com.alertetcl.shared.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Fichiers de la prévision Vélo'v servis par le relais sous `/velov-prevision/` et produits par le
 * robot hebdomadaire. Les clés que l'application ne connaît pas sont ignorées à la lecture.
 */

/** `index.json` : la version du modèle en ligne et la date de son dernier contrôle. */
@Serializable
internal data class VelovForecastIndex(
    val format: Int,
    /** Change à chaque nouveau modèle publié. */
    val version: String,
    /** Dernière fois que le robot a constaté que ce modèle reste juste sur des relevés récents (epoch, secondes). */
    @SerialName("verifie") val verifiedAt: Long
)

/** `modele.json` : tout ce qu'il faut pour calculer une prévision sans réseau. */
@Serializable
internal class VelovForecastBundle(
    val format: Int,
    val version: String,
    /** Noms des variables, dans l'ordre où les arbres les numérotent. */
    val variables: List<String>,
    /** Niveaux des déciles appris (10, 20… 90), un modèle `velos_q<niveau>` chacun. */
    val deciles: List<Int>,
    @SerialName("modeles") val forests: Map<String, VelovForecastForest>,
    /** Par station puis par « type de jour_heure » : les quatre moyennes habituelles, absentes (null) faute de relevés. */
    @SerialName("habitude") val habits: Map<String, Map<String, List<Double?>>> = emptyMap(),
    val stations: List<VelovForecastSite> = emptyList(),
    @SerialName("calendrier") val calendar: VelovForecastCalendar = VelovForecastCalendar()
) {
    companion object {
        /** Seul format que cette version de l'application sait lire. */
        const val FORMAT = 1
    }
}

/** Une forêt LightGBM : la prédiction est la somme des feuilles atteintes dans chaque arbre. */
@Serializable
internal class VelovForecastForest(
    /** Objectif d'entraînement ; `binary` et `cross_entropy` passent la somme par une sigmoïde. */
    @SerialName("objectif") val objective: String,
    @SerialName("arbres") val trees: List<VelovForecastTree>
)

/**
 * Un arbre aplati en tableaux, un élément par nœud interne. Un enfant positif ou nul est un autre
 * nœud ; un enfant négatif `e` désigne la feuille `leaves[~e]`.
 */
@Serializable
internal class VelovForecastTree(
    /** Rang, dans `variables`, de la variable testée par chaque nœud. */
    @SerialName("f") val features: IntArray,
    @SerialName("s") val thresholds: DoubleArray,
    /** `decision_type` de LightGBM : bit 0 catégoriel, bit 1 valeur manquante à gauche, bits 2-3 nature du manquant. */
    @SerialName("d") val decisions: IntArray,
    @SerialName("g") val left: IntArray,
    @SerialName("r") val right: IntArray,
    @SerialName("v") val leaves: DoubleArray,
    /** Premier nœud ; négatif quand l'arbre se réduit à une feuille. */
    @SerialName("racine") val root: Int
)

/** Ce que le modèle sait d'une station en dehors de son état : où elle est et ce qui l'entoure. */
@Serializable
internal class VelovForecastSite(
    val id: Int,
    val altitude: Double = Double.NaN,
    @SerialName("dist_metro_km") val metroKm: Double = Double.NaN,
    @SerialName("dist_tram_km") val tramKm: Double = Double.NaN,
    @SerialName("dist_gare_km") val railKm: Double = Double.NaN,
    val lat: Double = Double.NaN,
    val lon: Double = Double.NaN
)

@Serializable
internal class VelovForecastCalendar(
    /** Jours fériés au format `yyyy-MM-dd`. */
    @SerialName("feries") val holidays: List<String> = emptyList(),
    /** Vacances scolaires : paires [début, fin exclue] en millisecondes epoch. */
    @SerialName("vacances") val schoolHolidays: List<List<Long>> = emptyList()
)
