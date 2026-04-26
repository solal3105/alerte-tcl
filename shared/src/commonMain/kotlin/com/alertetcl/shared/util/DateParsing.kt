package com.alertetcl.shared.util

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant

/** Parse une date ISO 8601 (avec ou sans fractional seconds). */
fun parseIsoEpoch(s: String?): Long? {
    if (s.isNullOrEmpty()) return null
    return try {
        Instant.parse(s).epochSeconds
    } catch (_: Throwable) {
        null
    }
}

/** Parse une chaîne `yyyy-MM-dd HH:mm:ss` en epoch seconds (timezone Paris). */
fun parsePassageEpoch(s: String?): Long? {
    if (s.isNullOrEmpty()) return null
    return try {
        val parts = s.split(" ")
        if (parts.size != 2) return null
        val (date, time) = parts
        val dParts = date.split("-")
        val tParts = time.split(":")
        if (dParts.size < 3 || tParts.size < 3) return null
        val ldt = LocalDateTime(
            dParts[0].toInt(), dParts[1].toInt(), dParts[2].toInt(),
            tParts[0].toInt(), tParts[1].toInt(), tParts[2].toInt()
        )
        ldt.toInstant(TimeZone.of("Europe/Paris")).epochSeconds
    } catch (_: Throwable) {
        null
    }
}

/** Parse `yyyy-MM-dd` en epoch seconds (start of day, Paris). */
fun parseDateEpoch(s: String?): Long? {
    if (s.isNullOrEmpty()) return null
    return try {
        val parts = s.split("-")
        if (parts.size < 3) return null
        val ldt = LocalDateTime(parts[0].toInt(), parts[1].toInt(), parts[2].toInt(), 0, 0, 0)
        ldt.toInstant(TimeZone.of("Europe/Paris")).epochSeconds
    } catch (_: Throwable) {
        null
    }
}

/** Parse une durée ISO 8601 (`PT5M30S`, `-PT2M`) en secondes (signe préservé). */
fun parseDurationSeconds(s: String?): Int {
    if (s.isNullOrEmpty()) return 0
    val isNeg = s.startsWith("-")
    val clean = if (isNeg) s.substring(1) else s
    val regex = Regex("PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?")
    val m = regex.matchEntire(clean) ?: return 0
    val (h, mn, sc) = m.destructured
    val total = (h.toIntOrNull() ?: 0) * 3600 +
                (mn.toIntOrNull() ?: 0) * 60 +
                (sc.toIntOrNull() ?: 0)
    return if (isNeg) -total else total
}
