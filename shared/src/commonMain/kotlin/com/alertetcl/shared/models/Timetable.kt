package com.alertetcl.shared.models

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.minus
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.Serializable

/**
 * Fiches horaires théoriques (GTFS SYTRAL découpé par horaires/build_timetables.py).
 * Le format des fichiers est décrit dans horaires/README.md.
 */

/** Clé de fichier d'une ligne : majuscules, lettres et chiffres uniquement (identique au script Python). */
object TimetableKeys {
    fun keyFor(line: String): String = line.uppercase().filter { it in 'A'..'Z' || it in '0'..'9' }
}

/** Heures des fiches : minutes depuis minuit ; une valeur ≥ 1440 est un passage après minuit. */
object TimetableTime {
    const val MINUTES_PER_DAY = 1440

    /** Heure du changement de journée de service : avant 4 h du matin, on est encore sur la veille. */
    const val SERVICE_DAY_START_HOUR = 4
    const val SERVICE_DAY_START_MINUTES = SERVICE_DAY_START_HOUR * 60

    fun format(minutes: Int): String {
        val m = ((minutes % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY
        return "${(m / 60).toString().padStart(2, '0')}:${(m % 60).toString().padStart(2, '0')}"
    }

    fun isAfterMidnight(minutes: Int): Boolean = minutes >= MINUTES_PER_DAY

    /** Journée de service courante (les passages de nuit sont rattachés à la veille). */
    fun serviceDate(now: LocalDateTime): LocalDate =
        if (now.hour < SERVICE_DAY_START_HOUR) now.date.minus(1, DateTimeUnit.DAY) else now.date

    /** Minutes écoulées dans la journée de service courante (après minuit : 1440 + heure). */
    fun serviceMinutes(now: LocalDateTime): Int =
        now.hour * 60 + now.minute + (if (now.hour < SERVICE_DAY_START_HOUR) MINUTES_PER_DAY else 0)

    // Variantes sans types kotlinx.datetime, pour l'appel depuis Swift.

    private fun localNow(epochMillis: Long, timeZoneId: String): LocalDateTime =
        Instant.fromEpochMilliseconds(epochMillis).toLocalDateTime(TimeZone.of(timeZoneId))

    /** Journée de service courante au format `yyyy-MM-dd`. */
    fun serviceDateIso(epochMillis: Long, timeZoneId: String): String =
        serviceDate(localNow(epochMillis, timeZoneId)).toString()

    fun serviceMinutes(epochMillis: Long, timeZoneId: String): Int =
        serviceMinutes(localNow(epochMillis, timeZoneId))

    /** Date `yyyy-MM-dd` décalée de [days] jours. */
    fun addDays(isoDate: String, days: Int): String =
        LocalDate.parse(isoDate).plus(days, DateTimeUnit.DAY).toString()
}

@Serializable
data class TimetableIndex(
    val format: Int = 1,
    val generatedAt: String = "",
    val validFrom: String,
    val validTo: String,
    val lines: List<TimetableLineSummary> = emptyList()
) {
    val validToDate: LocalDate by lazy { LocalDate.parse(validTo) }

    /** Vrai quand les fiches n'ont pas été renouvelées : le jour demandé dépasse le dernier jour couvert. */
    fun isStaleOn(date: LocalDate): Boolean = date > validToDate
    fun isStaleOn(isoDate: String): Boolean = isStaleOn(LocalDate.parse(isoDate))

    fun line(name: String): TimetableLineSummary? {
        val key = TimetableKeys.keyFor(name)
        return lines.firstOrNull { it.key == key }
    }

    /** Terminus de chaque sens des fiches, `"ligne|A"` / `"ligne|R"` → destination affichée. */
    fun termini(): Map<String, String> =
        lines.flatMap { line -> line.directions.filter { it.headsign.isNotBlank() }.map { "${line.line}|${it.dir}" to it.headsign } }.toMap()
}

@Serializable
data class TimetableLineSummary(
    val line: String,
    val key: String,
    val mode: String = "bus",
    /** Couleurs officielles du pictogramme (`#RRGGBB`), vides si le GTFS n'en fournit pas. */
    val color: String = "",
    val textColor: String = "",
    val directions: List<TimetableDirectionSummary> = emptyList()
)

@Serializable
data class TimetableDirectionSummary(
    val dir: String,
    val headsign: String,
    val stops: Int = 0,
    val trips: Int = 0
)

@Serializable
data class TimetableStop(val id: Int, val name: String)

/** Arrêt présenté dans la liste d'un sens : un nom, et les indices des quais qui le portent. */
data class TimetableStopGroup(val name: String, val stopIndexes: List<Int>)

/** Une course : motif d'arrêts [p], calendrier [s], heures de passage [t] (une par arrêt du motif). */
@Serializable
data class TimetableTrip(val p: Int, val s: Int, val t: List<Int>)

/** Passage d'une course à un arrêt donné. */
data class TimetableDeparture(
    /** Minutes depuis minuit de la journée de service (≥ 1440 après minuit). */
    val minutes: Int,
    val tripIndex: Int,
    val stopIndex: Int,
    /** Terminus réel de la course (peut différer de la destination de la ligne : course partielle). */
    val terminus: String,
    /** True si l'arrêt est le dernier de la course (arrivée, pas de départ). */
    val isTerminus: Boolean,
    /** Décalage ajouté aux heures brutes de la course (1440 pour une course de nuit datée du lendemain par le GTFS). */
    val shiftMinutes: Int = 0
) {
    val time: String get() = TimetableTime.format(minutes)
}

/** Un arrêt d'une course avec son heure. [position] : rang dans la course (un arrêt peut revenir sur une boucle). */
data class TimetableCall(val position: Int, val stopIndex: Int, val stop: TimetableStop, val minutes: Int) {
    val time: String get() = TimetableTime.format(minutes)
}

@Serializable
data class LineTimetable(
    val format: Int = 1,
    val line: String,
    val key: String,
    val dir: String,
    val mode: String = "bus",
    val color: String = "",
    val textColor: String = "",
    val headsign: String = "",
    val validFrom: String,
    val validTo: String,
    val stops: List<TimetableStop> = emptyList(),
    val patterns: List<List<Int>> = emptyList(),
    val services: List<List<Int>> = emptyList(),
    val trips: List<TimetableTrip> = emptyList()
) {
    val validFromDate: LocalDate by lazy { LocalDate.parse(validFrom) }
    val validToDate: LocalDate by lazy { LocalDate.parse(validTo) }

    /** Position de chaque arrêt dans chaque motif (null si le motif ne le dessert pas). */
    private val positionInPattern: List<Map<Int, Int>> by lazy {
        patterns.map { pattern -> pattern.withIndex().associate { (pos, stopIndex) -> stopIndex to pos } }
    }
    private val serviceDays: List<Set<Int>> by lazy { services.map { it.toSet() } }

    /** Décalage de [date] par rapport au premier jour couvert, ou null hors période. */
    fun dayOffset(date: LocalDate): Int? {
        val offset = date.toEpochDays() - validFromDate.toEpochDays()
        val last = validToDate.toEpochDays() - validFromDate.toEpochDays()
        return offset.takeIf { it in 0..last }
    }

    fun isValidOn(date: LocalDate): Boolean = dayOffset(date) != null

    /**
     * Arrêts du sens sans doublon : le GTFS distingue les quais d'un même arrêt par des identifiants
     * différents sous le même nom ; on les regroupe, dans l'ordre de première apparition.
     */
    val stopGroups: List<TimetableStopGroup> by lazy {
        val groups = linkedMapOf<String, MutableList<Int>>()
        stops.forEachIndexed { index, stop -> groups.getOrPut(stop.name.trim().lowercase()) { mutableListOf() }.add(index) }
        groups.values.map { indexes -> TimetableStopGroup(stops[indexes.first()].name, indexes) }
    }

    /** Vrai quand la fiche n'a pas été renouvelée : le jour demandé dépasse le dernier jour couvert. */
    fun isStaleOn(date: LocalDate): Boolean = date > validToDate
    fun isStaleOn(isoDate: String): Boolean = isStaleOn(LocalDate.parse(isoDate))

    /** Variante Swift : date au format `yyyy-MM-dd`. */
    fun isValidOn(isoDate: String): Boolean = isValidOn(LocalDate.parse(isoDate))

    /** Variante Swift : identifiants d'arrêts en liste. */
    fun stopIndexesForIds(stopIds: List<Int>, stopName: String?): List<Int> = stopIndexes(stopIds.toSet(), stopName)

    /**
     * Indices des arrêts de cette fiche correspondant à un arrêt physique (un ou plusieurs
     * identifiants GeoServer). Si aucun identifiant ne correspond, on retombe sur le nom.
     */
    fun stopIndexes(stopIds: Set<Int>, stopName: String? = null): List<Int> {
        val byId = stops.indices.filter { stops[it].id in stopIds }
        if (byId.isNotEmpty() || stopName == null) return byId
        return stops.indices.filter { DirectionMatching.namesMatch(stops[it].name, stopName) }
    }

    /**
     * Vrai quand l'arrêt n'est que le terminus de ce sens : les courses y arrivent, aucune n'en part
     * (un arrêt de départ d'une boucle qui y revient n'est pas concerné). Faux si la fiche ne connaît
     * pas l'arrêt.
     */
    fun isArrivalOnly(stopIndexes: Collection<Int>): Boolean {
        val used = patterns.filter { pattern -> pattern.any { it in stopIndexes } }
        return used.isNotEmpty() && used.all { pattern -> pattern.indices.filter { pattern[it] in stopIndexes }.all { it == pattern.lastIndex } }
    }

    /** Variante Swift : journée de service au format `yyyy-MM-dd`. */
    fun departures(stopIndexes: List<Int>, isoDate: String): List<TimetableDeparture> =
        departures(stopIndexes, LocalDate.parse(isoDate))

    /**
     * Passages aux arrêts [stopIndexes] pour la journée de service [date], triés par heure.
     *
     * Une journée de service court de 4 h du matin au dernier service de la nuit. Le GTFS SYTRAL date
     * les courses de nuit du lendemain calendaire, à 00:xx : elles sont reprises ici avec 1440 minutes
     * de plus (« +1 »), et les courses d'avant 4 h datées du jour même, qui appartiennent à la nuit
     * précédente, sont écartées. Les heures déjà écrites ≥ 1440 (notation 25:00) restent telles quelles.
     */
    fun departures(stopIndexes: Collection<Int>, date: LocalDate): List<TimetableDeparture> {
        if (stopIndexes.isEmpty()) return emptyList()
        val result = ArrayList<TimetableDeparture>()
        dayOffset(date)?.let { offset ->
            collectDepartures(offset, stopIndexes, result) { minutes -> minutes.takeIf { it >= TimetableTime.SERVICE_DAY_START_MINUTES } }
        }
        dayOffset(date.plus(1, DateTimeUnit.DAY))?.let { offset ->
            collectDepartures(offset, stopIndexes, result, shiftMinutes = TimetableTime.MINUTES_PER_DAY) { minutes ->
                minutes.takeIf { it < TimetableTime.SERVICE_DAY_START_MINUTES }?.plus(TimetableTime.MINUTES_PER_DAY)
            }
        }
        result.sortWith(compareBy({ it.minutes }, { it.tripIndex }))
        return result
    }

    /** Ajoute à [result] les passages des courses actives au jour [offset], l'heure passée par [keep] (null = écartée). */
    private inline fun collectDepartures(
        offset: Int,
        stopIndexes: Collection<Int>,
        result: MutableList<TimetableDeparture>,
        shiftMinutes: Int = 0,
        keep: (Int) -> Int?
    ) {
        val active = serviceDays.indices.filter { offset in serviceDays[it] }.toSet()
        if (active.isEmpty()) return
        trips.forEachIndexed { tripIndex, trip ->
            if (trip.s !in active) return@forEachIndexed
            val positions = positionInPattern.getOrNull(trip.p) ?: return@forEachIndexed
            for (stopIndex in stopIndexes) {
                val pos = positions[stopIndex] ?: continue
                val minutes = keep(trip.t[pos]) ?: continue
                val pattern = patterns[trip.p]
                result.add(
                    TimetableDeparture(
                        minutes = minutes,
                        tripIndex = tripIndex,
                        stopIndex = stopIndex,
                        terminus = stops[pattern.last()].name,
                        isTerminus = pos == pattern.lastIndex,
                        shiftMinutes = shiftMinutes
                    )
                )
            }
        }
    }

    /** Tous les arrêts d'une course avec leurs heures, dans l'ordre de passage. */
    fun calls(tripIndex: Int): List<TimetableCall> = calls(tripIndex, 0)

    /** Variante avec le décalage d'une course de nuit ([TimetableDeparture.shiftMinutes]) : ses heures passent en « +1 ». */
    fun calls(tripIndex: Int, shiftMinutes: Int): List<TimetableCall> {
        val trip = trips.getOrNull(tripIndex) ?: return emptyList()
        val pattern = patterns.getOrNull(trip.p) ?: return emptyList()
        return pattern.mapIndexed { pos, stopIndex -> TimetableCall(pos, stopIndex, stops[stopIndex], trip.t[pos] + shiftMinutes) }
    }
}

/** Textes des fiches horaires, identiques sur les deux plateformes. */
object TimetableTexts {
    /** Avertissement quand les fiches n'ont pas pu être renouvelées ; [validToLong] est la date en toutes lettres. */
    fun staleNotice(validToLong: String): String =
        "Ces horaires ne sont plus à jour : ils étaient valables jusqu'au $validToLong. " +
            "Les nouvelles fiches n'ont pas encore pu être chargées ; fiez-vous aux prochains passages affichés à l'arrêt."
}
