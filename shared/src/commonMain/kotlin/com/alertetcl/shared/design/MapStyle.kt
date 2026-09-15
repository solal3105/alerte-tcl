package com.alertetcl.shared.design

import com.alertetcl.shared.models.TransportMode

/** Style des tracés de lignes sur la carte, identique sur iOS et Android. */
object MapStyle {
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
