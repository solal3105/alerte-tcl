package com.alertetcl.shared.design

import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.models.TravauxAvancement
import com.alertetcl.shared.models.TravauxImportance
import com.alertetcl.shared.models.VehicleType

/** Une couleur en deux variantes selon le thème du téléphone, au format `#RRGGBB`. */
data class ThemedColor(val light: String, val dark: String) {
    fun hex(darkTheme: Boolean): String = if (darkTheme) dark else light
}

/**
 * Jetons de couleur de l'application, identiques sur iOS et Android.
 *
 * Les couleurs des lignes viennent de [com.alertetcl.shared.models.LineColors] (palette officielle
 * du GTFS). Tout le reste est ici : l'accent, les états, les modes de transport (iconographie
 * seulement, jamais pour désigner une ligne précise) et les barèmes métier des travaux et parkings.
 * Chaque plateforme convertit ces hexadécimaux en couleur native ; aucune vue ne définit
 * sa propre couleur sémantique.
 */
object AppColors {
    /**
     * Accent de l'application : le même bleu sur les deux plateformes, quel que soit le fond
     * d'écran. La variante sombre reste lisible en texte sur fond sombre et en fond de bouton
     * avec du texte blanc.
     */
    val accent = ThemedColor("#1565C0", "#0A84FF")

    // ── États ───────────────────────────────────────────────────────────────
    val success = ThemedColor("#2E7D32", "#66BB6A")
    val warning = ThemedColor("#EF6C00", "#FFA726")
    val error = ThemedColor("#D32F2F", "#EF5350")
    val info: ThemedColor get() = accent

    /** Fraîcheur d'une position temps réel : récente, vieillissante, obsolète. */
    val fresh: ThemedColor get() = success
    val aging: ThemedColor get() = warning
    val stale: ThemedColor get() = error

    /** Étoile des favoris. */
    val favorite = ThemedColor("#F9A825", "#FFD54F")

    // ── Neutres ─────────────────────────────────────────────────────────────
    /** Texte ou icône sans signification particulière (case non cochée, valeur absente). */
    val neutral: ThemedColor get() = parkingUnknown
    /** Fond discret (pastille non retenue, badge « +3 », ligne dont la couleur est inconnue). */
    val neutralFill = ThemedColor("#E5E5EA", "#3A3A3C")
    /** Liseré autour d'un fond clair. */
    val neutralBorder = ThemedColor("#C7C7CC", "#48484A")
    /** Texte sur fond clair. */
    val onLight = "#1B1B1F"

    /** Marqueur d'un arrêt sur la carte (hors couleur de ligne). */
    val stopMarker = "#1976D2"
    /** Noyau des arrêts de bus, et des bus C, sur la carte ; métro et tram prennent la couleur de leur ligne. */
    val stopMarkerBus = "#808C9E"
    val stopMarkerBusC = "#1A338C"
    /** Tracé d'une ligne dont la couleur officielle n'est pas encore connue. */
    val routeUnknown = "#999999"

    /** Sévérité d'une alerte trafic. */
    fun alertSeverity(severity: AlertSeverity): ThemedColor = when (severity) {
        AlertSeverity.MAJOR -> error
        AlertSeverity.DISRUPTION -> warning
        AlertSeverity.INFO -> info
    }

    // ── Modes de transport (icônes des filtres et des onglets) ──────────────
    fun mode(mode: TransportMode): String = when (mode) {
        TransportMode.METRO -> "#FF9500"
        TransportMode.TRAMWAY -> "#007AFF"
        TransportMode.FUNICULAR -> "#34C759"
        TransportMode.BUS_C -> "#AF52DE"
        TransportMode.BUS -> "#5856D6"
        TransportMode.NAVIGONE -> "#32ADE6"
    }

    fun vehicleType(type: VehicleType): String = when (type) {
        VehicleType.METRO -> mode(TransportMode.METRO)
        VehicleType.TRAM -> mode(TransportMode.TRAMWAY)
        VehicleType.FUNICULAR -> mode(TransportMode.FUNICULAR)
        VehicleType.TROLLEY -> "#DAA520"
        VehicleType.NAVIGONE -> mode(TransportMode.NAVIGONE)
        VehicleType.BUS -> mode(TransportMode.BUS)
    }

    // ── Parkings ────────────────────────────────────────────────────────────
    /** Disponibilité inconnue (pas de temps réel) ou parking fermé. */
    val parkingUnknown = ThemedColor("#8E8E93", "#98989D")
    /** Rouge des Vélo'v, pour le type dans le sélecteur des parkings ; la disponibilité garde son barème. */
    val velov = ThemedColor("#C62828", "#EF5350")

    fun parkingAvailability(color: AvailabilityColor): ThemedColor = when (color) {
        AvailabilityColor.GRAY -> parkingUnknown
        AvailabilityColor.GREEN -> success
        AvailabilityColor.ORANGE -> warning
        AvailabilityColor.RED -> error
    }

    /** Couleur d'un type de parking dans les filtres et les regroupements ; les voitures suivent la disponibilité. */
    fun parkingType(type: ParkingType): ThemedColor = when (type) {
        ParkingType.CAR -> accent
        ParkingType.BIKE -> success
        ParkingType.MOTORIZED_2W -> warning
        ParkingType.VELOV -> velov
    }

    // ── Travaux ─────────────────────────────────────────────────────────────
    /** Importance d'un chantier ; `null` quand elle n'est pas renseignée (couleur neutre de la plateforme). */
    fun travauxImportance(importance: TravauxImportance): ThemedColor? = when (importance) {
        TravauxImportance.TRES_PERTURBANT -> error
        TravauxImportance.PERTURBANT -> warning
        TravauxImportance.PEU_PERTURBANT -> success
        TravauxImportance.INCONNU -> null
    }

    /** État d'un chantier : prévu, en cours, terminé ; `null` quand il n'est pas renseigné. */
    fun travauxAvancement(avancement: TravauxAvancement): ThemedColor? = when (avancement) {
        TravauxAvancement.PREVU -> accent
        TravauxAvancement.EN_COURS -> warning
        TravauxAvancement.TERMINE -> success
        TravauxAvancement.INCONNU -> null
    }

    /** Avancement d'un chantier (0 à 100 %) : du rouge au vert, en onze paliers. */
    fun travauxProgress(percent: Double): String = when {
        percent < 10 -> "#DC2626"
        percent < 20 -> "#EF4444"
        percent < 30 -> "#F97316"
        percent < 40 -> "#FB923C"
        percent < 50 -> "#FBBF24"
        percent < 60 -> "#EAB308"
        percent < 70 -> "#CA8A04"
        percent < 80 -> "#84CC16"
        percent < 90 -> "#65A30D"
        percent < 100 -> "#22C55E"
        else -> "#16A34A"
    }
}
