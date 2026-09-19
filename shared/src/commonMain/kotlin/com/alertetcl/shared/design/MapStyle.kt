package com.alertetcl.shared.design

import com.alertetcl.shared.models.TransportMode
import kotlin.math.log2

/** Style des tracés de lignes sur la carte, identique sur iOS et Android. */
object MapStyle {
    // ── Grille de zoom (niveaux de carte, identiques sur les deux plateformes) ──
    /** En dessous, chaque véhicule n'est qu'un point coloré ; au-dessus, un disque avec le numéro de ligne et sa flèche. */
    const val ZOOM_VEHICLE_BODY = 13.5
    /** À partir de ce zoom, les arrêts (et, dans l'onglet Parkings, les stations) apparaissent. */
    const val ZOOM_STOPS = 14.5
    /** À partir de ce zoom, les arrêts portent les badges de leurs lignes. */
    const val ZOOM_STOP_BADGES = 16.0

    /** Niveau de zoom d'une carte iOS : largeur visible en degrés de longitude pour [widthPoints] points d'écran. */
    fun zoomLevel(longitudeDelta: Double, widthPoints: Double): Double =
        log2(360.0 * widthPoints / (256.0 * longitudeDelta))

    /** Épaisseur du tracé selon le mode (points iOS, pixels indépendants de la densité sur Android). */
    fun routeWidth(mode: TransportMode): Double = when (mode) {
        TransportMode.METRO -> 4.0
        TransportMode.TRAMWAY -> 3.5
        TransportMode.FUNICULAR -> 3.0
        TransportMode.BUS_C -> 2.5
        TransportMode.BUS, TransportMode.NAVIGONE -> 2.0
    }

    fun routeWidth(line: String): Double = routeWidth(TransportMode.detectFromLine(line))

    /** Opacité des tracés : la carte reste lisible dessous. */
    val routeOpacity: Double = 0.9

    /** Liseré clair sous le tracé, pour le détacher du fond de carte. */
    val routeCasingExtraWidth: Double = 2.0
    val routeCasingOpacity: Double = 0.6
}
