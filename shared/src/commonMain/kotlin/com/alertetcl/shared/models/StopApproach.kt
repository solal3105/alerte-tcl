package com.alertetcl.shared.models

import kotlinx.datetime.LocalDate
import kotlin.math.abs

/** Un véhicule qui n'a pas encore atteint l'arrêt demandé, avec ce qu'on sait de son arrivée. */
data class ApproachingVehicle(
    val vehicle: Vehicle,
    /** Arrêts que le véhicule doit encore desservir avant l'arrêt demandé (0 : c'est son prochain arrêt). */
    val stopsBefore: Int,
    /** Heure prévue de passage à l'arrêt pour la course identifiée (minutes de la journée de service), null sans course identifiée. */
    val scheduledMinutes: Int?,
    /**
     * Arrivée estimée (epoch, secondes) : l'horaire prévu de la course corrigé du retard constaté par TCL
     * à la dernière position transmise. Null quand la course n'a pas pu être identifiée.
     */
    val estimatedArrivalEpoch: Long?
) {
    val stopsText: String get() = when (stopsBefore) {
        0 -> "Au prochain arrêt"
        1 -> "À 1 arrêt"
        else -> "À $stopsBefore arrêts"
    }

    /** Grand chiffre de la fiche d'arrêt : « 3 », ou « Arrive » quand l'arrêt est le prochain. */
    val stopsValue: String get() = if (stopsBefore == 0) "Arrive" else "$stopsBefore"

    /** Légende sous le grand chiffre (« Arrive au prochain arrêt », « 3 arrêts avant le vôtre »). */
    val stopsCaption: String get() = when (stopsBefore) {
        0 -> "au prochain arrêt"
        1 -> "arrêt avant le vôtre"
        else -> "arrêts avant le vôtre"
    }

    /** Une seule ligne sous les chiffres : l'âge de la position, pour rappeler qu'elle n'est pas en direct. */
    fun freshnessLine(nowEpochMs: Long): String =
        vehicle.positionAgeSeconds(nowEpochMs)?.let { "Position transmise par TCL il y a ${Vehicle.formattedAge(it)}" }
            ?: "Position sans horodatage"

    /** Heure prévue « HH:mm », null sans course identifiée. */
    val scheduledTime: String? get() = scheduledMinutes?.let { TimetableTime.format(it) }

    /** Heure d'arrivée estimée « HH:mm » dans le fuseau [timeZoneId], null sans estimation. */
    fun estimatedTime(timeZoneId: String = StopApproach.TIME_ZONE): String? =
        estimatedArrivalEpoch?.let { TimetableTime.format(TimetableTime.serviceMinutes(it * 1000, timeZoneId)) }

    /** « dans 4 min », ou « imminent » quand l'estimation est atteinte ; null sans estimation. */
    fun arrivalText(nowEpochMs: Long): String? {
        val eta = estimatedArrivalEpoch ?: return null
        val remaining = eta - nowEpochMs / 1000
        return if (remaining < 60) "imminent" else "dans ${remaining / 60} min"
    }

    /** « position transmise il y a 40 s » : la donnée n'est pas un suivi en direct, l'âge doit rester visible. */
    fun positionText(nowEpochMs: Long): String =
        vehicle.positionAgeSeconds(nowEpochMs)?.let { "position transmise il y a ${Vehicle.formattedAge(it)}" }
            ?: "position sans horodatage"
}

/**
 * « Où est mon bus » : croise les positions SIRI (prochain arrêt, horaire prévu, retard) avec la fiche
 * horaire d'un sens pour dire, à un arrêt, à combien d'arrêts se trouve chaque véhicule qui y vient et
 * quand il devrait y arriver. Rien n'est extrapolé depuis la position elle-même : l'estimation est
 * l'horaire prévu de la course corrigé du retard constaté par TCL, et l'âge de la position est affiché.
 */
object StopApproach {
    const val TIME_ZONE = "Europe/Paris"

    /** Quand aucun véhicule du sens n'est en route vers l'arrêt : la fonction reste visible. */
    const val NONE_APPROACHING = "Aucun bus en route vers cet arrêt pour l'instant."

    /** Phrase d'explication affichée sous les estimations, identique sur les deux plateformes. */
    const val NOTE = "Ces positions ne sont pas un suivi en direct : TCL les transmet toutes les 15 à 60 s, " +
        "le bus a pu avancer depuis. L'heure d'arrivée est celle de l'horaire prévu, corrigée du retard " +
        "constaté à la dernière transmission."

    /**
     * Véhicules de la ligne et du sens de [timetable] qui vont encore desservir l'arrêt ([stopIds] :
     * identifiants GeoServer de l'arrêt physique, [stopName] en secours), les plus proches d'abord.
     */
    fun approaching(
        vehicles: List<Vehicle>,
        timetable: LineTimetable,
        stopIds: List<Int>,
        stopName: String,
        nowEpochMs: Long,
        timeZoneId: String = TIME_ZONE,
        limit: Int = 3
    ): List<ApproachingVehicle> {
        val targets = timetable.stopIndexes(stopIds.toSet(), stopName).toSet()
        if (targets.isEmpty()) return emptyList()
        val serviceDate = LocalDate.parse(TimetableTime.serviceDateIso(nowEpochMs, timeZoneId))
        val result = ArrayList<ApproachingVehicle>()
        for (vehicle in vehicles) {
            if (TimetableKeys.keyFor(vehicle.lineName) != timetable.key) continue
            if (vehicle.direction.isNotEmpty() && vehicle.direction != timetable.dir) continue
            val next = vehicle.nextStop ?: continue
            val nextId = next.numericId ?: continue
            val nextIndexes = timetable.stops.indices.filter { timetable.stops[it].id == nextId }
            if (nextIndexes.isEmpty()) continue
            val approach = fromIdentifiedTrip(vehicle, next, nextIndexes, targets, timetable, serviceDate, timeZoneId)
                ?: fromStopOrder(vehicle, nextIndexes, targets, timetable)
                ?: continue
            result.add(approach)
        }
        result.sortWith(compareBy({ it.stopsBefore }, { it.estimatedArrivalEpoch ?: Long.MAX_VALUE }))
        return result.take(limit)
    }

    /** Course reconnue par l'heure prévue au prochain arrêt : nombre d'arrêts et estimation d'arrivée. */
    private fun fromIdentifiedTrip(
        vehicle: Vehicle,
        next: StopInfo,
        nextIndexes: List<Int>,
        targets: Set<Int>,
        timetable: LineTimetable,
        serviceDate: LocalDate,
        timeZoneId: String
    ): ApproachingVehicle? {
        val aimedEpoch = next.aimedArrivalTimeEpoch ?: next.aimedDepartureTimeEpoch ?: return null
        val aimedMinutes = TimetableTime.serviceMinutes(aimedEpoch * 1000, timeZoneId)
        val candidates = timetable.departures(nextIndexes, serviceDate).filter { abs(it.minutes - aimedMinutes) <= 1 }
        for (departure in candidates) {
            val calls = timetable.calls(departure.tripIndex)
            val nextCall = calls.firstOrNull { it.stopIndex == departure.stopIndex && it.minutes == departure.minutes } ?: continue
            val target = calls.drop(nextCall.position).firstOrNull { it.stopIndex in targets } ?: continue
            val eta = aimedEpoch + (target.minutes - nextCall.minutes) * 60L + vehicle.delay
            return ApproachingVehicle(vehicle, target.position - nextCall.position, target.minutes, eta)
        }
        return null
    }

    /** Course inconnue : on compte les arrêts sur l'ordre du sens (quais regroupés), sans heure. */
    private fun fromStopOrder(
        vehicle: Vehicle,
        nextIndexes: List<Int>,
        targets: Set<Int>,
        timetable: LineTimetable
    ): ApproachingVehicle? {
        val groups = timetable.stopGroups
        val nextGroup = groups.indexOfFirst { group -> group.stopIndexes.any { it in nextIndexes } }
        val targetGroup = groups.indexOfFirst { group -> group.stopIndexes.any { it in targets } }
        if (nextGroup < 0 || targetGroup < nextGroup) return null
        return ApproachingVehicle(vehicle, targetGroup - nextGroup, null, null)
    }
}
