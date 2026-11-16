package com.alertetcl.shared.models

import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant

/**
 * Les pastilles « Nouveau » qui signalent une nouveauté jusqu'à ce qu'on l'ait ouverte, ou jusqu'à une
 * date fixée d'avance. La même réponse allume la pastille de la tuile et celle de l'onglet qui la porte.
 * Chaque plateforme retient elle-même si la nouveauté a été ouverte.
 */
object NewBadges {
    const val LABEL = "Nouveau"

    /** Fin de la pastille de la prévision Vélo'v : le 1er mars 2027 à minuit, heure de Lyon. */
    private val VELOV_FORECAST_END_EPOCH_MS =
        LocalDateTime(2027, 3, 1, 0, 0).toInstant(TimeZone.of("Europe/Paris")).toEpochMilliseconds()

    /**
     * La pastille de la prévision Vélo'v, sur la tuile « Stations Vélo'v » et sur l'onglet « Autour de
     * moi » : tant que la carte des Vélo'v n'a pas été ouverte ([opened]), qu'une prévision peut s'y
     * montrer ([forecastAvailable] : pas de pastille pour une nouveauté qui n'afficherait rien) et que
     * la date de fin n'est pas passée.
     */
    fun showsVelovForecast(opened: Boolean, forecastAvailable: Boolean, nowEpochMs: Long): Boolean =
        !opened && forecastAvailable && nowEpochMs < VELOV_FORECAST_END_EPOCH_MS
}
