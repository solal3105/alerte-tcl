package com.alertetcl.shared.models

import kotlin.math.max

/**
 * Où en est un passage à un arrêt. Un seul état, calculé par [StopBoard], que lisent la liste des
 * prochains passages, la grille horaire et la carte : un bus à un arrêt de l'usager est « À l'approche »
 * partout, jamais « 3 min » à un endroit et « 22:54 » à un autre.
 */
enum class PassagePhase {
    /** Horaire prévu (fiche horaire ou passage théorique TCL), sans suivi en direct. */
    SCHEDULED,
    /** Suivi en direct, à plus d'une minute. */
    LIVE,
    /** Moins d'une minute, ou l'arrêt de l'usager est le prochain du véhicule, qui y est attendu sous trois minutes. */
    APPROACHING,
    /** Le véhicule est à l'arrêt de l'usager. */
    AT_STOP,
    /** Déjà passé : seule la grille horaire l'affiche, en grisé. */
    DEPARTED;

    val isLive: Boolean get() = this == LIVE || this == APPROACHING || this == AT_STOP
}

/** Un passage à venir et ce qu'on en sait. */
data class PassageStatus(
    val phase: PassagePhase,
    /**
     * Arrivée retenue (epoch, secondes) : l'estimation tirée de la position du véhicule quand il est
     * reconnu (flux le plus frais), sinon l'annonce TCL, sinon la fiche horaire.
     */
    val arrivalEpoch: Long,
    /** Heure prévue de la course à cet arrêt (minutes de la journée de service) : relie le passage à la grille. */
    val scheduledMinutes: Int?,
    /** Véhicule reconnu pour ce passage, avec sa distance en arrêts. */
    val approach: ApproachingVehicle?,
    /** Destination d'une course qui s'arrête avant le terminus (« Debourg »). */
    val shortDestination: String?,
    /** Départ de la journée de service suivante (fiche horaire, la nuit). */
    val isTomorrow: Boolean = false
) {
    private fun remainingSeconds(nowEpochMs: Long): Long = arrivalEpoch - nowEpochMs / 1000

    /** Heure exacte « HH:mm ». */
    fun time(timeZoneId: String = StopApproach.TIME_ZONE): String =
        TimetableTime.format(TimetableTime.serviceMinutes(arrivalEpoch * 1000, timeZoneId))

    /** Vrai quand le gros texte est une heure (départ lointain ou du lendemain) plutôt qu'un délai ou un mot. */
    fun headlineIsTime(nowEpochMs: Long): Boolean =
        (phase == PassagePhase.LIVE || phase == PassagePhase.SCHEDULED) &&
            (isTomorrow || remainingSeconds(nowEpochMs) >= PassageTexts.MINUTES_UNTIL_SECONDS)

    /**
     * Le gros texte : un délai (« 4 min »), un mot (« À l'approche », « À l'arrêt ») ou, pour un départ
     * à plus d'une heure, l'heure. Jamais une heure passée. « ~ » quand la position du véhicule date.
     */
    fun headline(nowEpochMs: Long, timeZoneId: String = StopApproach.TIME_ZONE): String = when (phase) {
        PassagePhase.AT_STOP -> PassageTexts.AT_STOP
        PassagePhase.APPROACHING -> PassageTexts.APPROACHING
        PassagePhase.DEPARTED -> PassageTexts.DEPARTED
        PassagePhase.LIVE, PassagePhase.SCHEDULED -> if (headlineIsTime(nowEpochMs)) time(timeZoneId) else {
            val approximate = approach?.vehicle?.positionFreshness(nowEpochMs) == PositionFreshness.AGING
            "${if (approximate) "~" else ""}${max(1L, remainingSeconds(nowEpochMs) / 60)} min"
        }
    }

    /**
     * La petite ligne sous le gros texte : l'heure exacte quand elle est à venir (« 22:54 », « prévu
     * 23:33 »), « demain » ou « prévu » quand le gros texte est déjà une heure, rien sinon.
     */
    fun caption(nowEpochMs: Long, timeZoneId: String = StopApproach.TIME_ZONE): String? = when {
        headlineIsTime(nowEpochMs) -> if (isTomorrow) PassageTexts.TOMORROW else if (phase == PassagePhase.SCHEDULED) PassageTexts.SCHEDULED else null
        remainingSeconds(nowEpochMs) < 0 -> null
        phase == PassagePhase.SCHEDULED -> "${PassageTexts.SCHEDULED} ${time(timeZoneId)}"
        else -> time(timeZoneId)
    }

    /** Heure courte pour « Ensuite » : « 23:35 », « demain 05:12 ». */
    fun shortTime(timeZoneId: String = StopApproach.TIME_ZONE): String =
        if (isTomorrow) "${PassageTexts.TOMORROW} ${time(timeZoneId)}" else time(timeZoneId)

    /**
     * Où est le véhicule par rapport à l'arrêt de l'usager : « À votre arrêt », « Prochain arrêt : le
     * vôtre », « Vers Génovéfains, l'arrêt d'avant », « Vers Choulans, 3 arrêts avant le vôtre ».
     * Null sans véhicule reconnu.
     */
    val location: String? get() {
        val approach = approach ?: return null
        if (phase == PassagePhase.AT_STOP) return PassageTexts.AT_YOUR_STOP
        val next = approach.vehicle.nextStop?.stopName?.takeIf { it.isNotBlank() && it.toIntOrNull() == null }
        return when (approach.stopsBefore) {
            0 -> PassageTexts.NEXT_IS_YOURS
            1 -> if (next != null) "Vers $next, l'arrêt d'avant" else "1 arrêt avant le vôtre"
            else -> "${if (next != null) "Vers $next, " else ""}${approach.stopsBefore} arrêts avant le vôtre"
        }
    }
}

/** Les mots des passages, identiques sur les deux plateformes. */
object PassageTexts {
    /** Au-delà d'une heure, un départ s'écrit à l'heure plutôt qu'en minutes. */
    const val MINUTES_UNTIL_SECONDS = 3600L

    const val AT_STOP = "À l'arrêt"
    const val APPROACHING = "À l'approche"
    const val DEPARTED = "Passé"
    const val SCHEDULED = "prévu"
    const val TOMORROW = "demain"
    const val AT_YOUR_STOP = "À votre arrêt"
    const val NEXT_IS_YOURS = "Prochain arrêt : le vôtre"
    const val LAST_OF_DAY = "Dernier passage"
    const val THEN = "Ensuite"
    const val LAST = "dernier"
    const val NONE_ANNOUNCED = "Aucun passage annoncé pour l'instant."
    const val NONE_PLANNED = "Aucun passage prévu aujourd'hui ni demain."

    /** Un sens sans passage : rien de prévu quand la fiche horaire est connue, sinon rien d'annoncé. */
    fun noPassage(timetableKnown: Boolean): String = if (timetableKnown) NONE_PLANNED else NONE_ANNOUNCED

    /**
     * La petite ligne à côté du gros texte d'une carte : l'heure exacte, « jusqu'à Debourg » pour une
     * course qui s'arrête avant le terminus, « Dernier passage ». Null quand il n'y a rien à ajouter.
     */
    fun headlineDetail(board: LineBoard, nowEpochMs: Long, timeZoneId: String = StopApproach.TIME_ZONE): String? {
        val first = board.first ?: return null
        return listOfNotNull(
            first.caption(nowEpochMs, timeZoneId),
            first.shortDestination?.let { "jusqu'à $it" },
            LAST_OF_DAY.takeIf { board.firstIsLast }
        ).joinToString(" · ").ifEmpty { null }
    }

    /** Un passage de la liste « En direct » d'une fiche horaire : l'heure exacte, puis où est le véhicule. */
    fun rowDetail(status: PassageStatus, nowEpochMs: Long, timeZoneId: String = StopApproach.TIME_ZONE): String? =
        listOfNotNull(status.caption(nowEpochMs, timeZoneId), status.location).joinToString(" · ").ifEmpty { null }

    /** « Ensuite 23:35 · dernier 00:12 », « Dernier 00:12 », null quand il n'y a rien après le premier passage. */
    fun thenLine(board: LineBoard, timeZoneId: String = StopApproach.TIME_ZONE): String? {
        val last = board.lastDeparture?.let { "$LAST ${it.shortTime(timeZoneId)}" }
        if (board.following.isEmpty()) return last?.replaceFirstChar { it.uppercase() }
        return "$THEN ${(board.following.map { it.shortTime(timeZoneId) } + listOfNotNull(last)).joinToString(" · ")}"
    }
}
