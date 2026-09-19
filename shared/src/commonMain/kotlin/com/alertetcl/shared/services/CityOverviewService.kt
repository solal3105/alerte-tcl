package com.alertetcl.shared.services

import com.alertetcl.shared.models.CityOverview
import com.alertetcl.shared.models.ParkingState
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.models.TravauxAvancement
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

/**
 * Chiffres de l'accueil « Autour de moi », chargés en parallèle et indépendamment : une source en
 * panne laisse les autres tuiles renseignées.
 */
class CityOverviewService(
    private val parkingService: ParkingService = ParkingService.shared,
    private val velovService: VelovService = VelovService.shared,
    private val travauxService: TravauxService = TravauxService.shared
) {
    suspend fun fetch(): CityOverview = coroutineScope {
        val cars = async {
            runCatching {
                parkingService.fetchParkings(ParkingType.CAR)
                    .filter { it.hasRealtimeData && it.etat == ParkingState.OUVERT }
                    .sumOf { it.placesDisponibles }
            }.getOrNull()
        }
        val bikes = async { runCatching { velovService.fetchStations().filter { it.open }.sumOf { it.bikes } }.getOrNull() }
        val travaux = async { runCatching { travauxService.fetchTravaux().count { it.avancement == TravauxAvancement.EN_COURS } }.getOrNull() }
        CityOverview(carFreePlaces = cars.await(), velovBikes = bikes.await(), travauxInProgress = travaux.await())
    }

    companion object { val shared = CityOverviewService() }
}
