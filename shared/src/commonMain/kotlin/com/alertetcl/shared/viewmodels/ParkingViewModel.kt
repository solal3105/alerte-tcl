package com.alertetcl.shared.viewmodels

import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.services.ParcRelaisService
import com.alertetcl.shared.services.ParkingService
import com.alertetcl.shared.services.VelovService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope

class ParkingViewModel(
    private val parkingService: ParkingService = ParkingService.shared,
    private val parcRelaisService: ParcRelaisService = ParcRelaisService.shared,
    private val velovService: VelovService = VelovService.shared
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** Requête de chargement en cours — annulée à chaque nouveau viewport. */
    private var loadJob: Job? = null

    private val _parkings = MutableStateFlow<List<Parking>>(emptyList())
    val parkings: StateFlow<List<Parking>> = _parkings.asStateFlow()

    /** Stations Vélo'v, remplies seulement quand ce type est sélectionné. */
    private val _velovStations = MutableStateFlow<List<VelovStation>>(emptyList())
    val velovStations: StateFlow<List<VelovStation>> = _velovStations.asStateFlow()

    private val _selectedTypes = MutableStateFlow(setOf(ParkingType.CAR))
    val selectedTypes: StateFlow<Set<ParkingType>> = _selectedTypes.asStateFlow()

    private val _showParcRelais = MutableStateFlow(true)
    val showParcRelais: StateFlow<Boolean> = _showParcRelais.asStateFlow()

    /** Affiche les parkings voiture temps réel (sinon seuls les P+R restent). */
    private val _showRealtimeParkings = MutableStateFlow(true)
    val showRealtimeParkings: StateFlow<Boolean> = _showRealtimeParkings.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _lastUpdateEpochMs = MutableStateFlow<Long?>(null)
    val lastUpdateEpochMs: StateFlow<Long?> = _lastUpdateEpochMs.asStateFlow()

    fun toggleType(type: ParkingType) {
        val cur = _selectedTypes.value.toMutableSet()
        if (!cur.add(type)) cur.remove(type)
        _selectedTypes.value = cur
    }

    /** Sélection exclusive d'un seul type (comportement radio, comme iOS). */
    fun setType(type: ParkingType) {
        _selectedTypes.value = setOf(type)
    }

    fun toggleParcRelais() {
        _showParcRelais.value = !_showParcRelais.value
    }

    fun toggleRealtimeParkings() {
        _showRealtimeParkings.value = !_showRealtimeParkings.value
    }

    fun loadInRegion(region: GeoRegion, forceRefresh: Boolean = false) {
        // Annule la requête précédente : une réponse lente d'un ancien viewport
        // ne doit pas écraser les données du viewport courant.
        loadJob?.cancel()
        loadJob = scope.launch {
            _isLoading.value = true
            val failures = mutableListOf<Throwable>()
            try {
                // Chaque source est interrogée séparément : une source en panne laisse les autres
                // s'afficher et n'emporte pas l'application. Sans ce cloisonnement, l'échec d'une
                // requête remonte à la coroutine parente avant d'être rattrapé et fait tomber l'app.
                supervisorScope {
                    val carsAsync = if (ParkingType.CAR in _selectedTypes.value && _showRealtimeParkings.value)
                        tolerant(failures) { parkingService.fetchParkings(ParkingType.CAR, forceRefresh) } else null
                    val bikesAsync = if (ParkingType.BIKE in _selectedTypes.value)
                        tolerant(failures) { parkingService.fetchParkingsInRegion(ParkingType.BIKE, region, forceRefresh) } else null
                    val motoAsync = if (ParkingType.MOTORIZED_2W in _selectedTypes.value)
                        tolerant(failures) { parkingService.fetchParkingsInRegion(ParkingType.MOTORIZED_2W, region, forceRefresh) } else null
                    val prAsync = if (ParkingType.CAR in _selectedTypes.value && _showParcRelais.value)
                        tolerant(failures) { parcRelaisService.fetchParcRelais(forceRefresh) } else null
                    val velovAsync = if (ParkingType.VELOV in _selectedTypes.value)
                        tolerant(failures) { velovService.fetchStations(forceRefresh) } else null

                    val all = listOfNotNull(
                        carsAsync?.await(),
                        bikesAsync?.await(),
                        motoAsync?.await(),
                        prAsync?.await()
                    ).flatten()

                    _parkings.value = all
                    _velovStations.value = velovAsync?.await() ?: emptyList()
                    _errorMessage.value = failures.firstOrNull()?.message
                    _lastUpdateEpochMs.value = kotlinx.datetime.Clock.System.now().toEpochMilliseconds()
                }
            } catch (e: CancellationException) {
                throw e // Annulation volontaire — ne pas la présenter comme une erreur
            } catch (e: Throwable) {
                AppLogger.error("ParkingViewModel error", e)
                _errorMessage.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Interroge une source sans faire tomber les autres : l'échec est retenu dans [failures] et la
     * requête rend `null`. Une annulation reste une annulation et se propage.
     */
    private fun <T> CoroutineScope.tolerant(
        failures: MutableList<Throwable>,
        fetch: suspend () -> List<T>
    ): Deferred<List<T>?> = async {
        try {
            fetch()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            AppLogger.error("ParkingViewModel source error", e)
            failures.add(e)
            null
        }
    }

    fun dispose() { scope.cancel() }
}
