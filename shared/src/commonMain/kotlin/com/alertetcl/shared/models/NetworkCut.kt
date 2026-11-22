package com.alertetcl.shared.models

import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.util.parsePassageEpoch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Coupures du réseau telles que le relais les publie (`/coupures`, format décrit dans
 * coupures/README.md). La lecture des textes de TCL se fait sur GitHub, pas dans l'application :
 * ce fichier n'en est que le résultat. Les dates sont à l'heure de Paris (`2026-11-23 21:20:00`).
 */
@Serializable
data class NetworkCutsFile(
    val format: Int,
    /** Dernière lecture qui a réécrit le fichier (ISO 8601, UTC). */
    val genere: String,
    val coupures: List<NetworkCut> = emptyList(),
    /** Alertes « ne circule pas » que la lecture n'a pas su placer : pastille sans tracé. */
    val nonPlacees: List<NetworkCut> = emptyList()
)

@Serializable
data class NetworkCut(
    /** Identité de l'alerte TCL, la même que [AlertIdentity]. */
    val id: String,
    val ligne: String,
    val mode: String = "bus",
    val couleur: String = "",
    val titre: String = "",
    val message: String = "",
    @SerialName("fenetres") val windows: List<CutWindowDto> = emptyList(),
    /** Le texte parle de certains moments sans dire lesquels : les fenêtres couvrent toute la période. */
    @SerialName("horairesPartiels") val partialTimes: Boolean = false,
    /** Le titre cite d'autres jours que la période publiée, qui fait foi. */
    @SerialName("datesContradictoires") val conflictingDates: Boolean = false,
    @SerialName("destinations") val destinations: Map<String, String> = emptyMap(),
    @SerialName("effets") val effects: List<CutEffect> = emptyList(),
    @SerialName("traits") val traces: List<CutTrace> = emptyList(),
    @SerialName("arrets") val stops: List<CutStop> = emptyList(),
    @SerialName("bornes") val bounds: List<CutStop> = emptyList()
) {
    /** Toute la ligne est coupée (texte « ne circule pas »). */
    val wholeLine: Boolean get() = effects.any { it.whole }

    /** La lecture a su placer la coupure (tracé ou arrêts) ; sinon c'est une alerte « sans service » de [NetworkCutsFile.nonPlacees]. */
    val placed: Boolean get() = traces.isNotEmpty() || stops.isNotEmpty()

    /** Fenêtres en secondes epoch, dans l'ordre ; une fin inconnue reste ouverte. */
    val epochWindows: List<CutWindow> by lazy {
        windows.mapNotNull { w -> parsePassageEpoch(w.start)?.let { CutWindow(it, parsePassageEpoch(w.end)) } }
    }

    /** Sens touchés (« A », « R ») ; vide quand le fichier ne le dit pas. */
    val directions: Set<String> get() =
        if (traces.any { it.bothDirections }) setOf("A", "R") else (traces.map { it.direction } + stops.map { it.direction }).toSet()
}

@Serializable
data class CutWindowDto(@SerialName("debut") val start: String, @SerialName("fin") val end: String? = null)

/** Fenêtre d'une coupure : [start] et [end] en secondes epoch, [end] null quand TCL n'en donne pas. */
data class CutWindow(val start: Long, val end: Long?) {
    fun contains(epoch: Long): Boolean = epoch >= start && (end == null || epoch < end)
}

@Serializable
data class CutEffect(
    @SerialName("effet") val kind: String,
    @SerialName("sens") val direction: String? = null,
    @SerialName("toute") val whole: Boolean = false
)

@Serializable
data class CutTrace(
    @SerialName("sens") val direction: String,
    /** Le même tronçon vaut pour les deux sens. */
    @SerialName("deuxSens") val bothDirections: Boolean = false,
    /** Points `[lon, lat]`. */
    @SerialName("points") val lonLat: List<List<Double>> = emptyList()
) {
    val points: List<LatLng> by lazy { lonLat.mapNotNull { LatLng.fromGeoJSON(it) } }
}

@Serializable
data class CutStop(
    @SerialName("nom") val name: String,
    @SerialName("sens") val direction: String,
    @SerialName("lon") val longitude: Double,
    @SerialName("lat") val latitude: Double
) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)
}
