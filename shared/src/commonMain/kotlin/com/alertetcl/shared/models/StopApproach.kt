package com.alertetcl.shared.models

import kotlinx.datetime.LocalDate
import kotlin.math.abs

/** Un véhicule qui n'a pas encore atteint l'arrêt demandé, avec ce qu'on sait de son arrivée. */
data class ApproachingVehicle(
    val vehicle: Vehicle,
    /** Arrêts que le véhicule doit encore desservir avant l'arrêt demandé (0 : c'est son prochain arrêt). */
    val stopsBefore: Int,
    /** L'arrêt vers lequel il roule (nom de la fiche horaire), null s'il est inconnu. */
    val towardStopName: String?,
    /** Heure prévue de passage à l'arrêt pour la course identifiée (minutes de la journée de service), null sans course identifiée. */
    val scheduledMinutes: Int?,
    /**
     * Arrivée estimée (epoch, secondes) : l'horaire prévu de la course corrigé du retard constaté par TCL
     * à la dernière position transmise. Null quand la course n'a pas pu être identifiée.
     */
    val estimatedArrivalEpoch: Long?
)

/**
 * Où est mon bus : croise les positions SIRI (prochain arrêt, horaire prévu, retard) avec la fiche
 * horaire d'un sens pour dire, à un arrêt, à combien d'arrêts se trouve chaque véhicule qui y vient et
 * quand il devrait y arriver. Rien n'est extrapolé depuis la position elle-même : l'estimation est
 * l'horaire prévu de la course corrigé du retard constaté par TCL. [StopBoard] ne la montre que
 * rattachée à un passage annoncé.
 */
object StopApproach {
    const val TIME_ZONE = "Europe/Paris"

    /**
     * Un véhicule attendu à son prochain arrêt dans plus d'une heure n'est pas en route : sa course n'a
     * pas commencé (dépôt) ou ses horaires sont incohérents, comme ce bus à trois arrêts annoncé deux
     * heures plus tard.
     */
    const val NEXT_STOP_HORIZON_SECONDS = 3600L

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
            if ((vehicle.nextStopArrivalEpoch ?: nowSec) - nowSec > NEXT_STOP_HORIZON_SECONDS) continue
            val next = vehicle.nextStop ?: continue
            val nextId = next.numericId ?: continue
            val nextIndexes = timetable.stops.indices.filter { timetable.stops[it].id == nextId }
            if (nextIndexes.isEmpty()) continue
            // L'arrêt donné par TCL est le dernier suivi : son heure passée, le véhicule roule vers le suivant.
            val passed = if (vehicle.hasPassedNextStop(nowEpochMs)) 1 else 0
            val approach = fromIdentifiedTrip(vehicle, next, nextIndexes, passed, targets, timetable, serviceDate, timeZoneId)
                ?: fromStopOrder(vehicle, nextIndexes, passed, targets, timetable)
                ?: continue
            result.add(approach)
        }
        result.sortWith(compareBy({ it.stopsBefore }, { it.estimatedArrivalEpoch ?: Long.MAX_VALUE }))
        return result.take(limit)
    }

    /**
     * Course reconnue par l'heure prévue à l'arrêt donné par TCL : nombre d'arrêts et estimation d'arrivée.
     * [passed] vaut 1 quand le véhicule a déjà dépassé cet arrêt.
     */
    private fun fromIdentifiedTrip(
        vehicle: Vehicle,
        next: StopInfo,
        nextIndexes: List<Int>,
        passed: Int,
        targets: Set<Int>,
        timetable: LineTimetable,
        serviceDate: LocalDate,
        timeZoneId: String
    ): ApproachingVehicle? {
        val aimedEpoch = next.aimedArrivalTimeEpoch ?: next.aimedDepartureTimeEpoch ?: return null
        val aimedMinutes = TimetableTime.serviceMinutes(aimedEpoch * 1000, timeZoneId)
        val candidates = timetable.departures(nextIndexes, serviceDate).filter { abs(it.minutes - aimedMinutes) <= 1 }
        for (departure in candidates) {
            val calls = timetable.calls(departure.tripIndex, departure.shiftMinutes)
            val nextCall = calls.firstOrNull { it.stopIndex == departure.stopIndex && it.minutes == departure.minutes } ?: continue
            val onward = calls.drop(nextCall.position + passed)
            val target = onward.firstOrNull { it.stopIndex in targets } ?: continue
            val toward = onward.first()
            val eta = aimedEpoch + (target.minutes - nextCall.minutes) * 60L + vehicle.delay
            return ApproachingVehicle(vehicle, target.position - toward.position, toward.stop.name, target.minutes, eta)
        }
        return null
    }

    /** Course inconnue : on compte les arrêts sur l'ordre du sens (quais regroupés), sans heure. */
    private fun fromStopOrder(
        vehicle: Vehicle,
        nextIndexes: List<Int>,
        passed: Int,
        targets: Set<Int>,
        timetable: LineTimetable
    ): ApproachingVehicle? {
        val groups = timetable.stopGroups
        val nextGroup = groups.indexOfFirst { group -> group.stopIndexes.any { it in nextIndexes } }
        val targetGroup = groups.indexOfFirst { group -> group.stopIndexes.any { it in targets } }
        val towardGroup = nextGroup + passed
        if (nextGroup < 0 || targetGroup < towardGroup) return null
        return ApproachingVehicle(vehicle, targetGroup - towardGroup, groups[towardGroup].name, null, null)
    }
}
