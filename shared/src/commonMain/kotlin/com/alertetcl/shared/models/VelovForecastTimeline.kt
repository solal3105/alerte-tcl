package com.alertetcl.shared.models

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.isoDayNumber
import kotlinx.datetime.toLocalDateTime

/** Un repère sur un axe des heures : sa place entre le départ (0) et la dernière échéance (1), et ce qu'on y écrit. */
data class VelovForecastTick(val position: Double, val label: String)

/**
 * Les heures d'une prévision Vélo'v, à l'heure de Lyon, pour la fiche d'une station comme pour le curseur
 * de la carte. L'échéance 0 est le départ ([originEpochMs], l'heure où l'état des stations a été relevé),
 * les 96 suivantes tombent tous les quarts d'heure.
 *
 * Une heure s'écrit « 19 h 15 », arrondie à cinq minutes : une prévision n'est pas juste à la minute,
 * et le départ tombe rarement sur un quart d'heure rond. Le jour (« demain ») est celui de cette heure
 * arrondie, comparé au jour du départ.
 */
internal class VelovForecastTimeline(private val originEpochMs: Long) {
    private val originDate = local(originEpochMs).date

    /** « 19 h 15 », « 9 h » */
    fun clock(step: Int): String {
        val time = shown(step)
        return if (time.minute == 0) "${time.hour} h" else "${time.hour} h ${time.minute.toString().padStart(2, '0')}"
    }

    /** Vrai si l'échéance tombe un autre jour que le départ : sur 24 h, c'est le lendemain. */
    fun isNextDay(step: Int): Boolean = shown(step).date != originDate

    /** Les heures rondes multiples de [everyHours] (« 0 h », « 6 h »…) après le départ, jusqu'à la dernière échéance comprise. */
    fun ticks(everyHours: Int): List<VelovForecastTick> =
        wholeHours().filter { (_, time) -> time.hour % everyHours == 0 }.map { (position, time) -> VelovForecastTick(position, "${time.hour} h") }

    /** Minuit, avec le nom du jour qui commence (« mardi ») ; null les rares jours de 25 h où il tombe après la dernière échéance. */
    val midnight: VelovForecastTick?
        get() = wholeHours().firstOrNull { (_, time) -> time.hour == 0 }
            ?.let { (position, time) -> VelovForecastTick(position, WEEKDAYS[time.dayOfWeek.isoDayNumber - 1]) }

    private fun shown(step: Int): LocalDateTime {
        val exact = originEpochMs + step * VelovForecast.STEP_MS
        return local((exact + ROUNDING_MS / 2) / ROUNDING_MS * ROUNDING_MS)
    }

    /**
     * Chaque heure ronde après le départ, avec sa place sur l'axe. Les décalages de Lyon étant des
     * heures entières, une heure ronde l'est aussi en temps universel, changement d'heure compris.
     */
    private fun wholeHours(): List<Pair<Double, LocalDateTime>> {
        val first = (originEpochMs / HOUR_MS + 1) * HOUR_MS
        return (first..originEpochMs + SPAN_MS step HOUR_MS).map { (it - originEpochMs).toDouble() / SPAN_MS to local(it) }
    }

    companion object {
        /** L'échéance 0 : l'état réel des stations, pas une prévision. */
        const val NOW = "Maintenant"

        private val LYON = TimeZone.of("Europe/Paris")
        private val WEEKDAYS = listOf("lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche")
        private const val HOUR_MS = 3_600_000L
        private const val ROUNDING_MS = 300_000L
        private const val SPAN_MS = VelovForecast.STEP_COUNT * VelovForecast.STEP_MS

        private fun local(epochMs: Long): LocalDateTime = Instant.fromEpochMilliseconds(epochMs).toLocalDateTime(LYON)

        /** Place d'une échéance sur l'axe des heures, de 0 (départ) à 1 (dernière échéance). */
        fun position(step: Int): Double = step.toDouble() / VelovForecast.STEP_COUNT

        /** Ramène une échéance demandée par une vue entre le départ et la dernière. */
        fun bounded(step: Int): Int = step.coerceIn(0, VelovForecast.STEP_COUNT)

        /** Le temps d'ici une échéance : « 15 min », « 1 h », « 13 h 45 ». */
        fun delay(step: Int): String {
            val minutes = step * VelovForecast.STEP_MINUTES
            return when {
                minutes < 60 -> "$minutes min"
                minutes % 60 == 0 -> "${minutes / 60} h"
                else -> "${minutes / 60} h ${minutes % 60}"
            }
        }
    }
}
