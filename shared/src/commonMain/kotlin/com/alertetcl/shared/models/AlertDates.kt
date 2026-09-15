package com.alertetcl.shared.models

import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime

/** Libellés de dates des alertes, les mêmes sur les deux plateformes. */
object AlertDates {
    private val months = listOf("janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc.")

    /** Début d'une alerte : « Il y a 12 min », « 14:30 » (moins d'un jour) ou « 15 sept. ». */
    fun startLabel(epochSeconds: Long, nowEpochSeconds: Long, timeZoneId: String = "Europe/Paris"): String {
        val diff = nowEpochSeconds - epochSeconds
        if (diff in 0 until 3600) return "Il y a ${diff / 60} min"
        val local = Instant.fromEpochSeconds(epochSeconds).toLocalDateTime(TimeZone.of(timeZoneId))
        if (diff in 0 until 86_400) return time(local.hour, local.minute)
        return day(local.dayOfMonth, local.monthNumber, local.year, nowEpochSeconds, timeZoneId)
    }

    /** Fin d'une alerte : « Jusqu'au 15 sept. à 14:30 ». */
    fun endLabel(epochSeconds: Long, nowEpochSeconds: Long, timeZoneId: String = "Europe/Paris"): String {
        val local = Instant.fromEpochSeconds(epochSeconds).toLocalDateTime(TimeZone.of(timeZoneId))
        return "Jusqu'au ${day(local.dayOfMonth, local.monthNumber, local.year, nowEpochSeconds, timeZoneId)} à ${time(local.hour, local.minute)}"
    }

    private fun time(hour: Int, minute: Int): String =
        "${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}"

    private fun day(dayOfMonth: Int, month: Int, year: Int, nowEpochSeconds: Long, timeZoneId: String): String {
        val currentYear = Instant.fromEpochSeconds(nowEpochSeconds).toLocalDateTime(TimeZone.of(timeZoneId)).year
        val base = if (dayOfMonth == 1) "1er ${months[month - 1]}" else "$dayOfMonth ${months[month - 1]}"
        return if (year == currentYear) base else "$base $year"
    }
}
