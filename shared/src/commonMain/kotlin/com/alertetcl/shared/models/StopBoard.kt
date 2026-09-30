package com.alertetcl.shared.models

import com.alertetcl.shared.util.parsePassageEpoch
import kotlin.math.abs

/** Un sens d'une ligne à un arrêt, tel que la fiche de l'arrêt le montre. */
data class LineBoard(
    val group: PassageGroup,
    /** Passage mis en avant, null quand rien n'est annoncé ni prévu. */
    val first: PassageStatus?,
    /** Les passages suivants, deux au plus, avant le dernier de la journée qui a sa place à part. */
    val following: List<PassageStatus>,
    /** Dernier départ de la journée quand il approche, s'il n'est pas le passage mis en avant. */
    val lastDeparture: PassageStatus?,
    /** Le passage mis en avant est le dernier de la journée. */
    val firstIsLast: Boolean
)

/** La grille du jour lue avec l'état des passages : ce qui est passé, le départ suivi, le reste. */
data class TimetableGridState(
    /** Rang du prochain départ dans la grille, -1 quand la journée est finie. */
    val nextIndex: Int,
    /** État du prochain départ quand il est suivi en direct ou annoncé. */
    val next: PassageStatus?
) {
    fun phaseOf(index: Int): PassagePhase = when {
        nextIndex < 0 || index < nextIndex -> PassagePhase.DEPARTED
        index == nextIndex -> next?.phase ?: PassagePhase.SCHEDULED
        else -> PassagePhase.SCHEDULED
    }
}

/**
 * Les prochains passages d'un sens à un arrêt, en croisant trois sources qui ne se rafraîchissent pas
 * au même rythme : les annonces TCL de l'arrêt, les positions des véhicules ([StopApproach]) et la fiche
 * horaire. Un véhicule n'apparaît que rattaché à un passage annoncé, dont il donne alors l'heure (son
 * flux est le plus frais) : jamais un chiffre à part qu'on ne saurait relier à rien. L'état se recalcule
 * à chaque appel avec l'heure courante, de sorte qu'aucun délai ne reste figé entre deux rafraîchissements.
 */
object StopBoard {
    /** Écart maximal entre l'arrivée estimée d'un véhicule et une annonce TCL pour les rapprocher. */
    const val MATCH_WINDOW_SECONDS = 10 * 60L
    /** Une annonce en direct dépassée depuis moins longtemps reste « À l'approche » (le bus n'est pas encore passé). */
    const val ANNOUNCED_GRACE_SECONDS = 120L
    /** Distance au prochain arrêt, en mètres, sous laquelle le véhicule est considéré à l'arrêt. */
    const val AT_STOP_METRES = 30
    /**
     * Un véhicule dont l'arrêt de l'usager est le prochain n'est « À l'approche » qu'attendu dans moins de
     * trois minutes : au-delà, sa propre course le dit en attente (terminus, départ pas encore commencé) et
     * l'attente s'écrit en minutes.
     */
    const val NEXT_STOP_APPROACH_SECONDS = 3 * 60L
    /** Le dernier départ de la journée est rappelé quand il part dans moins de deux heures. */
    const val LAST_DEPARTURE_HORIZON_SECONDS = 2 * 3600L
    /** Retard et avance tolérés pour rattacher une annonce TCL à une course de la fiche horaire. */
    private const val LATE_MINUTES = 20
    private const val EARLY_MINUTES = 2

    /**
     * Le sens [group] tel qu'il s'affiche : le passage mis en avant, les suivants, le dernier de la
     * journée. [stopIndexes] : l'arrêt dans [timetable] (ignoré sans fiche).
     */
    fun board(
        group: PassageGroup,
        approaching: List<ApproachingVehicle>,
        timetable: LineTimetable?,
        stopIndexes: List<Int>,
        nowEpochMs: Long,
        timeZoneId: String = StopApproach.TIME_ZONE
    ): LineBoard {
        val upcoming = upcoming(group.passages, approaching, timetable, stopIndexes, nowEpochMs, timeZoneId, limit = 4, shortDestination = group::shortDestination)
        val first = upcoming.firstOrNull()
        val today = TimetableTime.serviceDateIso(nowEpochMs, timeZoneId)
        val last = timetable?.departures(stopIndexes, today)?.lastOrNull { !it.isTerminus }
        val lastEpoch = last?.let { TimetableTime.epochSeconds(today, it.minutes, timeZoneId) }
        val isLast = { status: PassageStatus -> last != null && !status.isTomorrow && status.scheduledMinutes == last.minutes }
        val firstIsLast = first != null && isLast(first)
        val showLast = last != null && lastEpoch != null && !firstIsLast && lastEpoch >= nowEpochMs / 1000 &&
            (lastEpoch - nowEpochMs / 1000 <= LAST_DEPARTURE_HORIZON_SECONDS || upcoming.take(3).any(isLast))
        val lastStatus = if (!showLast || last == null || lastEpoch == null) null
            else upcoming.firstOrNull(isLast) ?: PassageStatus(PassagePhase.SCHEDULED, lastEpoch, last.minutes, null, null)
        return LineBoard(
            group = group,
            first = first,
            // Quand le dernier départ est rappelé, rien ne s'écrit après lui (pas de passage du lendemain avant lui).
            following = upcoming.drop(1).filter { !isLast(it) && (lastStatus == null || it.arrivalEpoch < lastStatus.arrivalEpoch) }.take(2),
            lastDeparture = lastStatus,
            firstIsLast = firstIsLast
        )
    }

    /**
     * Passages à venir, les plus proches d'abord, chacun avec son état. Les annonces TCL passées de plus
     * de [ANNOUNCED_GRACE_SECONDS] disparaissent ; un véhicule « À l'approche » de l'arrêt de l'usager
     * reste affiché même si TCL ne l'annonce plus ; la fiche horaire complète jusqu'à [limit].
     */
    fun upcoming(
        passages: List<Passage>,
        approaching: List<ApproachingVehicle>,
        timetable: LineTimetable?,
        stopIndexes: List<Int>,
        nowEpochMs: Long,
        timeZoneId: String = StopApproach.TIME_ZONE,
        limit: Int = 3,
        shortDestination: (Passage) -> String? = { null }
    ): List<PassageStatus> {
        val nowSec = nowEpochMs / 1000
        val today = TimetableTime.serviceDateIso(nowEpochMs, timeZoneId)
        val todays = timetable?.departures(stopIndexes, today)?.filter { !it.isTerminus }.orEmpty()
        val claimed = HashSet<Int>()

        // Chaque véhicule en approche, du plus proche au plus lointain, prend l'annonce TCL qui lui
        // correspond ; les véhicules d'un même sens arrivent dans l'ordre. Sans course reconnue, seul un
        // véhicule dont le prochain arrêt est celui de l'usager se rattache sûrement : au premier passage.
        val announced = passages.mapNotNull { p -> parsePassageEpoch(p.heurepassage)?.let { p to it } }.sortedBy { it.second }
        val matched = arrayOfNulls<ApproachingVehicle>(announced.size)
        val arriving = ArrayList<ApproachingVehicle>()
        var cursor = 0
        for (approach in approaching.filter { it.vehicle.positionFreshness(nowEpochMs) != PositionFreshness.STALE }) {
            val eta = approach.estimatedArrivalEpoch
            val index = when {
                eta != null -> (cursor until announced.size)
                    .filter { abs(announced[it].second - eta) <= MATCH_WINDOW_SECONDS }
                    .minByOrNull { abs(announced[it].second - eta) }
                approach.stopsBefore == 0 -> cursor.takeIf { it < announced.size }
                else -> null
            }
            if (index != null) { matched[index] = approach; cursor = index + 1 }
            else if (approach.stopsBefore == 0) arriving.add(approach)
        }

        val result = ArrayList<PassageStatus>()
        announced.forEachIndexed { i, (passage, epoch) ->
            val approach = matched[i]
            val arrival = approach?.estimatedArrivalEpoch ?: epoch
            val phase = phase(approach, live = approach != null || passage.isRealTime, arrival, nowSec) ?: return@forEachIndexed
            val scheduled = approach?.scheduledMinutes?.also { claim(todays, claimed, it) }
                ?: scheduledFor(todays, claimed, epoch, timeZoneId)
            result.add(PassageStatus(phase, arrival, scheduled, approach, shortDestination(passage)))
        }
        // Un véhicule que TCL n'annonce plus mais dont l'arrêt de l'usager est le prochain : « À l'approche »,
        // jamais un délai à lui.
        for (approach in arriving) {
            val arrival = approach.estimatedArrivalEpoch ?: nowSec
            val phase = phase(approach, live = true, arrival, nowSec)?.takeIf { it != PassagePhase.LIVE } ?: continue
            approach.scheduledMinutes?.let { claim(todays, claimed, it) }
            result.add(PassageStatus(phase, arrival, approach.scheduledMinutes, approach, null))
        }

        // La fiche horaire prend la suite des annonces : après la dernière course connue, puis le lendemain.
        if (timetable != null && result.size < limit) {
            val after = result.mapNotNull { it.scheduledMinutes }.maxOrNull()
                ?: result.maxOfOrNull { TimetableTime.serviceMinutes(it.arrivalEpoch * 1000, timeZoneId) }
            todays.forEachIndexed { index, d ->
                if (result.size >= limit || index in claimed || (after != null && d.minutes <= after)) return@forEachIndexed
                val epoch = TimetableTime.epochSeconds(today, d.minutes, timeZoneId)
                if (epoch >= nowSec) result.add(PassageStatus(PassagePhase.SCHEDULED, epoch, d.minutes, null, null))
            }
            if (result.size < limit) {
                val tomorrow = TimetableTime.addDays(today, 1)
                timetable.departures(stopIndexes, tomorrow).filter { !it.isTerminus }.take(limit - result.size).forEach { d ->
                    result.add(PassageStatus(PassagePhase.SCHEDULED, TimetableTime.epochSeconds(tomorrow, d.minutes, timeZoneId), d.minutes, null, null, isTomorrow = true))
                }
            }
        }
        return result.sortedWith(compareBy({ rank(it.phase) }, { it.arrivalEpoch })).take(limit)
    }

    /**
     * Vrai quand ce sens ne fait qu'arriver à l'arrêt (terminus) : la fiche d'arrêt ne l'affiche pas,
     * personne n'y monte. Faux tant que la fiche ne connaît pas l'arrêt.
     */
    fun isArrivalOnly(timetable: LineTimetable, stopIds: List<Int>, stopName: String?): Boolean =
        timetable.isArrivalOnly(timetable.stopIndexes(stopIds.toSet(), stopName))

    /** La grille du jour [departures] (journée de service en cours) lue avec les passages à venir [upcoming]. */
    fun grid(departures: List<TimetableDeparture>, upcoming: List<PassageStatus>, nowEpochMs: Long, timeZoneId: String = StopApproach.TIME_ZONE): TimetableGridState {
        val first = upcoming.firstOrNull { !it.isTomorrow }
        // Sans passage rattaché à la fiche, un départ ne se grise qu'avec la marge d'une annonce dépassée.
        val threshold = first?.scheduledMinutes
            ?: (TimetableTime.serviceMinutes(nowEpochMs, timeZoneId) - (ANNOUNCED_GRACE_SECONDS / 60).toInt())
        val nextIndex = departures.indexOfFirst { it.minutes >= threshold }
        val next = first?.takeIf { nextIndex >= 0 && it.scheduledMinutes == departures[nextIndex].minutes }
        return TimetableGridState(nextIndex, next)
    }

    /** État d'un passage à l'instant [nowSec], null quand il est passé. */
    private fun phase(approach: ApproachingVehicle?, live: Boolean, arrival: Long, nowSec: Long): PassagePhase? {
        val remaining = arrival - nowSec
        if (approach != null) {
            if (approach.stopsBefore == 0) {
                val distance = approach.vehicle.nextStop?.distanceFromStop
                if (distance != null && distance <= AT_STOP_METRES) return PassagePhase.AT_STOP
                if (approach.estimatedArrivalEpoch == null || remaining < NEXT_STOP_APPROACH_SECONDS) return PassagePhase.APPROACHING
            }
            return if (remaining < 60) PassagePhase.APPROACHING else PassagePhase.LIVE
        }
        return when {
            !live -> if (remaining < 0) null else PassagePhase.SCHEDULED
            remaining < -ANNOUNCED_GRACE_SECONDS -> null
            remaining < 60 -> PassagePhase.APPROACHING
            else -> PassagePhase.LIVE
        }
    }

    private fun rank(phase: PassagePhase): Int = when (phase) {
        PassagePhase.AT_STOP -> 0
        PassagePhase.APPROACHING -> 1
        else -> 2
    }

    private fun claim(todays: List<TimetableDeparture>, claimed: MutableSet<Int>, minutes: Int) {
        todays.indices.firstOrNull { it !in claimed && todays[it].minutes == minutes }?.let { claimed.add(it) }
    }

    /** Course de la fiche la plus proche d'une annonce TCL (en retard de [LATE_MINUTES] au plus), réservée pour ne servir qu'une fois. */
    private fun scheduledFor(todays: List<TimetableDeparture>, claimed: MutableSet<Int>, epoch: Long, timeZoneId: String): Int? {
        val minutes = TimetableTime.serviceMinutes(epoch * 1000, timeZoneId)
        val index = todays.indices
            .filter { it !in claimed && todays[it].minutes in (minutes - LATE_MINUTES)..(minutes + EARLY_MINUTES) }
            .minByOrNull { abs(todays[it].minutes - minutes) }
            ?: return null
        claimed.add(index)
        return todays[index].minutes
    }
}
