package com.alertetcl.shared.models

import kotlinx.datetime.LocalDate
import kotlin.math.abs

/** Un véhicule qui n'a pas encore atteint l'arrêt demandé, avec ce qu'on sait de son arrivée. */
data class ApproachingVehicle(
    val vehicle: Vehicle,
    /** Arrêts entre le dernier atteint et l'arrêt demandé (0 : l'arrêt demandé est le suivant). */
    val stopsBefore: Int,
    /** Le dernier arrêt atteint (nom de la fiche horaire), null s'il est inconnu. */
    val lastStopName: String?,
    /** Heure prévue de passage à l'arrêt pour la course identifiée (minutes de la journée de service), null sans course identifiée. */
    val scheduledMinutes: Int?,
    /**
     * Arrivée estimée (epoch, secondes) : l'horaire prévu de la course corrigé du retard constaté par TCL
     * à la dernière position transmise. Null quand la course n'a pas pu être identifiée.
     */
    val estimatedArrivalEpoch: Long?
)

/**
 * Où est mon bus : croise les positions SIRI (dernier arrêt atteint, son horaire prévu, retard) avec la
 * fiche horaire d'un sens pour dire, à un arrêt, combien d'arrêts il reste à chaque véhicule qui y vient
 * et quand il devrait y arriver. TCL ne donne que le dernier arrêt atteint : on compte depuis le suivant,
 * et un véhicule dont le dernier arrêt est celui demandé y est déjà passé. Rien n'est extrapolé depuis la position elle-même : l'estimation est
 * l'horaire prévu de la course corrigé du retard constaté par TCL. [StopBoard] ne la montre que
 * rattachée à un passage annoncé.
 */
object StopApproach {
    const val TIME_ZONE = "Europe/Paris"

    /**
     * Un véhicule dont le dernier arrêt est prévu dans plus d'une heure n'est pas en route : sa course
     * n'a pas commencé (dépôt) ou ses horaires sont incohérents, comme ce bus à trois arrêts annoncé deux
     * heures plus tard.
     */
    const val LAST_STOP_HORIZON_SECONDS = 3600L

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
        val nowSec = nowEpochMs / 1000
        val result = ArrayList<ApproachingVehicle>()
        for (vehicle in vehicles) {
            if (TimetableKeys.keyFor(vehicle.lineName) != timetable.key) continue
            if (vehicle.direction.isNotEmpty() && vehicle.direction != timetable.dir) continue
            if ((vehicle.lastStopTimeEpoch ?: nowSec) - nowSec > LAST_STOP_HORIZON_SECONDS) continue
            val last = vehicle.lastStop ?: continue
            val lastId = last.numericId ?: continue
            val lastIndexes = timetable.stops.indices.filter { timetable.stops[it].id == lastId }
            if (lastIndexes.isEmpty()) continue
            val approach = fromIdentifiedTrip(vehicle, last, lastIndexes, targets, timetable, serviceDate, timeZoneId)
                ?: fromStopOrder(vehicle, lastIndexes, targets, timetable)
                ?: continue
            result.add(approach)
        }
        result.sortWith(compareBy({ it.stopsBefore }, { it.estimatedArrivalEpoch ?: Long.MAX_VALUE }))
        return result.take(limit)
    }

    /** Course reconnue par l'heure prévue au dernier arrêt atteint : nombre d'arrêts et estimation d'arrivée. */
    private fun fromIdentifiedTrip(
        vehicle: Vehicle,
        last: StopInfo,
        lastIndexes: List<Int>,
        targets: Set<Int>,
        timetable: LineTimetable,
        serviceDate: LocalDate,
        timeZoneId: String
    ): ApproachingVehicle? {
        val aimedEpoch = last.aimedArrivalTimeEpoch ?: last.aimedDepartureTimeEpoch ?: return null
        val aimedMinutes = TimetableTime.serviceMinutes(aimedEpoch * 1000, timeZoneId)
        val candidates = timetable.departures(lastIndexes, serviceDate).filter { abs(it.minutes - aimedMinutes) <= 1 }
        for (departure in candidates) {
            val calls = timetable.calls(departure.tripIndex, departure.shiftMinutes)
            val lastCall = calls.firstOrNull { it.stopIndex == departure.stopIndex && it.minutes == departure.minutes } ?: continue
            val target = calls.drop(lastCall.position + 1).firstOrNull { it.stopIndex in targets } ?: continue
            val eta = aimedEpoch + (target.minutes - lastCall.minutes) * 60L + vehicle.delay
            return ApproachingVehicle(vehicle, target.position - lastCall.position - 1, lastCall.stop.name, target.minutes, eta)
        }
        return null
    }

    /** Course inconnue : on compte les arrêts sur l'ordre du sens (quais regroupés), sans heure. */
    private fun fromStopOrder(
        vehicle: Vehicle,
        lastIndexes: List<Int>,
        targets: Set<Int>,
        timetable: LineTimetable
    ): ApproachingVehicle? {
        val groups = timetable.stopGroups
        val lastGroup = groups.indexOfFirst { group -> group.stopIndexes.any { it in lastIndexes } }
        val targetGroup = groups.indexOfFirst { group -> group.stopIndexes.any { it in targets } }
        if (lastGroup < 0 || targetGroup <= lastGroup) return null
        return ApproachingVehicle(vehicle, targetGroup - lastGroup - 1, groups[lastGroup].name, null, null)
    }
}
