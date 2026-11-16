package com.alertetcl.shared.models

/**
 * Le panneau du curseur d'heure sur la carte des stations Vélo'v. Le curseur va de l'échéance 0,
 * « Maintenant » (l'état réel, dessiné comme avant), à 96, dans 24 h, où les marqueurs deviennent des
 * [VelovForecastMarker]. Le panneau n'existe que si une prévision est disponible.
 */
data class VelovForecastMapPanel(
    /** « Maintenant », « Aujourd'hui à 19 h 45 », « Demain à 8 h 30 » */
    val title: String,
    /** « Glissez pour voir la prévision », à l'échéance 0 seulement. Aucun bouton n'y ramène : on y revient en glissant. */
    val hint: String?,
    /** Heures écrites sous le curseur, toutes les 3 h. */
    val ticks: List<VelovForecastTick>
) {
    companion object {
        private const val HINT = "Glissez pour voir la prévision"
        private const val TICK_HOURS = 3

        /** Le panneau pour des stations relevées à [originEpochMs], curseur sur [step] (ramené entre 0 et 96). */
        fun at(originEpochMs: Long, step: Int): VelovForecastMapPanel {
            val timeline = VelovForecastTimeline(originEpochMs)
            val shown = VelovForecastTimeline.bounded(step)
            val ticks = timeline.ticks(TICK_HOURS)
            if (shown == 0) return VelovForecastMapPanel(VelovForecastTimeline.NOW, HINT, ticks)
            val day = if (timeline.isNextDay(shown)) "Demain" else "Aujourd'hui"
            return VelovForecastMapPanel("$day à ${timeline.clock(shown)}", null, ticks)
        }
    }
}
