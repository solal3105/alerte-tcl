package com.alertetcl.shared.models

/**
 * Prochains départs théoriques d'un sens à un arrêt : ceux qui restent dans la journée de service,
 * sinon les premiers de la journée suivante ([isTomorrow]). Sert quand aucun passage n'est annoncé
 * en direct (la nuit, une ligne peu fréquente) et aux widgets.
 */
data class NextDepartures(
    /** Journée de service des départs, au format `yyyy-MM-dd`. */
    val isoDate: String,
    val isTomorrow: Boolean,
    val departures: List<TimetableDeparture>
)

object TimetableNext {
    /** Légende d'un départ théorique dans la liste des passages. */
    const val CAPTION_TODAY = "prévu"
    const val CAPTION_TOMORROW = "demain"
    /** Texte quand la fiche ne prévoit plus rien ni aujourd'hui ni demain. */
    const val NONE_PLANNED = "Aucun passage prévu aujourd'hui ni demain."

    /**
     * Vrai quand ce sens ne fait qu'arriver à l'arrêt (terminus) : la fiche d'arrêt ne l'affiche pas,
     * personne n'y monte. Faux tant que la fiche ne connaît pas l'arrêt.
     */
    fun isArrivalOnly(timetable: LineTimetable, stopIds: List<Int>, stopName: String?): Boolean =
        timetable.isArrivalOnly(timetable.stopIndexes(stopIds.toSet(), stopName))

    fun upcoming(
        timetable: LineTimetable,
        stopIds: List<Int>,
        stopName: String?,
        nowEpochMs: Long,
        timeZoneId: String,
        limit: Int = 3
    ): NextDepartures? {
        val indexes = timetable.stopIndexes(stopIds.toSet(), stopName)
        if (indexes.isEmpty()) return null
        val today = TimetableTime.serviceDateIso(nowEpochMs, timeZoneId)
        val nowMinutes = TimetableTime.serviceMinutes(nowEpochMs, timeZoneId)
        val left = timetable.departures(indexes, today).filter { it.minutes >= nowMinutes && !it.isTerminus }.take(limit)
        if (left.isNotEmpty()) return NextDepartures(today, false, left)
        val tomorrow = TimetableTime.addDays(today, 1)
        val first = timetable.departures(indexes, tomorrow).filter { !it.isTerminus }.take(limit)
        return if (first.isEmpty()) null else NextDepartures(tomorrow, true, first)
    }
}
