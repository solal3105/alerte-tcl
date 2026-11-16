package com.alertetcl.shared.viewmodels

import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecastMapPanel
import com.alertetcl.shared.models.VelovForecastMarker
import com.alertetcl.shared.models.VelovForecastSheet
import com.alertetcl.shared.models.VelovForecastTimeline
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.services.ParcRelaisService
import com.alertetcl.shared.services.ParkingService
import com.alertetcl.shared.services.VelovForecastService
import com.alertetcl.shared.services.VelovService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock

/** La fiche de station ouverte depuis la carte Vélo'v. */
data class VelovStationSelection(
    /** La station dans son dernier relevé. */
    val station: VelovStation,
    /** Sa prévision ; null s'il n'y en a pas à montrer, ou pas encore ([forecastPending]). */
    val forecast: VelovForecastSheet?,
    /** Vrai le temps du premier calcul : la fiche garde alors la place du graphique. */
    val forecastPending: Boolean,
    /** Vrai quand la fiche a été ouverte depuis celle d'une station voisine, où l'on peut revenir. */
    val hasPrevious: Boolean
)

class ParkingViewModel(
    private val parkingService: ParkingService = ParkingService.shared,
    private val parcRelaisService: ParcRelaisService = ParcRelaisService.shared,
    private val velovService: VelovService = VelovService.shared,
    private val velovForecastService: VelovForecastService = VelovForecastService.shared
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

    // ── Prévision Vélo'v ────────────────────────────────────────────────────

    /** Le dernier relevé rendu par [velovService] : une autre liste est un relevé neuf, la même une copie gardée. */
    private var velovReading: List<VelovStation>? = null

    /** Heure où [velovReading] est arrivé : le départ des prévisions, le même pour la carte et pour la fiche. */
    private var velovOriginEpochMs: Long? = null

    /** Vrai s'il y a des prévisions à montrer pour ce relevé ([VelovForecastService.isAvailable]). */
    private var velovForecastAvailable = false

    /** Le départ des prévisions quand il y en a à montrer, null sinon. */
    private val velovForecastOrigin: Long? get() = velovOriginEpochMs?.takeIf { velovForecastAvailable }

    /** Ce que comptent les marqueurs ; chaque plateforme garde ce choix et le donne par [setVelovFilter]. */
    private var velovFilter = VelovFilter.ALL

    private val _velovForecastPanel = MutableStateFlow<VelovForecastMapPanel?>(null)
    /** Le panneau du curseur d'heure de la carte ; null tant qu'il n'y a pas de prévision à montrer. */
    val velovForecastPanel: StateFlow<VelovForecastMapPanel?> = _velovForecastPanel.asStateFlow()

    private val _velovForecastStep = MutableStateFlow(0)
    /** L'échéance du curseur d'heure : 0 pour l'état réel, jusqu'à 96 pour dans 24 h. */
    val velovForecastStep: StateFlow<Int> = _velovForecastStep.asStateFlow()

    private val _velovForecastMarkers = MutableStateFlow<List<VelovForecastMarker>?>(null)
    /**
     * Les marqueurs prévus à l'échéance du curseur ; null quand la carte doit montrer l'état réel des
     * stations (échéance 0, ou première prévision pas encore calculée).
     */
    val velovForecastMarkers: StateFlow<List<VelovForecastMarker>?> = _velovForecastMarkers.asStateFlow()

    private val _velovSelection = MutableStateFlow<VelovStationSelection?>(null)
    /** La fiche de station ouverte, null quand aucune ne l'est. */
    val velovSelection: StateFlow<VelovStationSelection?> = _velovSelection.asStateFlow()

    /** Calcul de la prévision de la fiche ouverte, annulé quand une autre station la remplace. */
    private var selectionJob: Job? = null

    /** Les stations d'où l'on est passé à une voisine « plus sûre », la dernière quittée en fin de liste. */
    private var velovTrail: List<VelovStation> = emptyList()

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

    /** Le filtre de la carte Vélo'v a changé : les marqueurs prévus comptent autre chose. */
    fun setVelovFilter(filter: VelovFilter) {
        if (filter == velovFilter) return
        velovFilter = filter
        refreshVelovForecast()
    }

    /** Déplace le curseur d'heure de la carte ; sans prévision à montrer, il reste sur l'état réel. */
    fun setVelovForecastStep(step: Int) {
        val shown = if (velovForecastOrigin == null) 0 else VelovForecastTimeline.bounded(step)
        if (shown == _velovForecastStep.value) return
        _velovForecastStep.value = shown
        refreshVelovForecast()
    }

    /** Ouvre la fiche de [station] depuis la carte ; null la ferme. */
    fun selectVelovStation(station: VelovStation?) {
        velovTrail = emptyList()
        showVelovStation(station)
    }

    /** Passe de la fiche ouverte à celle d'une station voisine, en gardant le chemin du retour. */
    fun openVelovNeighbour(station: VelovStation) {
        _velovSelection.value?.let { velovTrail = velovTrail + it.station }
        showVelovStation(station)
    }

    /** Revient à la station d'où la fiche ouverte a été atteinte, dans son dernier relevé. */
    fun backToPreviousVelovStation() {
        val previous = velovTrail.lastOrNull() ?: return
        velovTrail = velovTrail.dropLast(1)
        showVelovStation(latestReading(previous))
    }

    /** [station] telle que le dernier relevé la donne. */
    private fun latestReading(station: VelovStation): VelovStation =
        _velovStations.value.firstOrNull { it.id == station.id } ?: station

    /**
     * Montre [station] dans la fiche (null la ferme) et calcule sa prévision, à partir du même relevé et
     * de la même heure de départ que la carte.
     */
    private fun showVelovStation(station: VelovStation?) {
        selectionJob?.cancel()
        if (station == null) {
            _velovSelection.value = null
            return
        }
        val hasPrevious = velovTrail.isNotEmpty()
        val origin = velovForecastOrigin
        // Station déjà ouverte (relevé neuf) : la fiche garde ce qu'elle montre le temps du recalcul.
        val open = _velovSelection.value?.takeIf { origin != null && it.station.id == station.id }
        _velovSelection.value = VelovStationSelection(
            station,
            open?.forecast,
            forecastPending = origin != null && (open == null || open.forecastPending),
            hasPrevious = hasPrevious
        )
        if (origin == null) return
        val stations = _velovStations.value
        selectionJob = scope.launch {
            val forecast = forecastOrNull { velovForecastService.sheet(station, stations, origin) }
            _velovSelection.value = VelovStationSelection(station, forecast, forecastPending = false, hasPrevious = hasPrevious)
        }
    }

    fun loadInRegion(region: GeoRegion, forceRefresh: Boolean = false) {
        // Annule la requête précédente : une réponse lente d'un ancien viewport
        // ne doit pas écraser les données du viewport courant.
        loadJob?.cancel()
        loadJob = scope.launch {
            _isLoading.value = true
            try {
                val carsAsync = if (ParkingType.CAR in _selectedTypes.value && _showRealtimeParkings.value)
                    async { parkingService.fetchParkings(ParkingType.CAR, forceRefresh) } else null
                val bikesAsync = if (ParkingType.BIKE in _selectedTypes.value)
                    async { parkingService.fetchParkingsInRegion(ParkingType.BIKE, region, forceRefresh) } else null
                val motoAsync = if (ParkingType.MOTORIZED_2W in _selectedTypes.value)
                    async { parkingService.fetchParkingsInRegion(ParkingType.MOTORIZED_2W, region, forceRefresh) } else null
                val prAsync = if (ParkingType.CAR in _selectedTypes.value && _showParcRelais.value)
                    async { parcRelaisService.fetchParcRelais(forceRefresh) } else null
                val velovAsync = if (ParkingType.VELOV in _selectedTypes.value) {
                    // Premier affichage des stations : le modèle de prévision se charge pendant que le
                    // relais répond, pour que la première fiche ouverte ait déjà sa prévision.
                    if (velovReading == null) velovForecastService.warmUp()
                    async { velovService.fetchStations(forceRefresh) }
                } else null

                val all = listOfNotNull(
                    carsAsync?.await(),
                    bikesAsync?.await(),
                    motoAsync?.await(),
                    prAsync?.await()
                ).flatten()

                _parkings.value = all
                showVelovReading(velovAsync?.await())
                _errorMessage.value = null
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
     * Range le relevé des stations ([stations] null : le type Vélo'v n'est pas affiché) et remet la
     * prévision d'accord avec lui.
     *
     * Un relevé neuf (toutes les minutes) déplace le départ des prévisions, mais pas le curseur d'heure :
     * il garde son échéance, « dans 2 h » reste « dans 2 h », recalculé depuis le nouveau relevé. La carte
     * montre les anciens marqueurs jusqu'à l'arrivée des nouveaux, et la fiche ouverte suit de la même façon.
     */
    private suspend fun showVelovReading(stations: List<VelovStation>?) {
        val fresh = stations !== velovReading
        val origin = if (fresh) stations?.let { Clock.System.now().toEpochMilliseconds() } else velovOriginEpochMs
        val available = origin != null && forecastOrNull { velovForecastService.isAvailable(origin) } == true
        if (!fresh && available == velovForecastAvailable) return
        // Plus rien ne suspend à partir d'ici : relevé, heure de départ et prévision changent ensemble.
        velovReading = stations
        _velovStations.value = stations ?: emptyList()
        velovOriginEpochMs = origin
        velovForecastAvailable = available
        if (!available) _velovForecastStep.value = 0
        refreshVelovForecast()
        _velovSelection.value?.let { open -> showVelovStation(latestReading(open.station)) }
    }

    /** Remet le panneau et les marqueurs de la carte d'accord avec le relevé, l'échéance et le filtre. */
    private fun refreshVelovForecast() {
        val origin = velovForecastOrigin
        val step = _velovForecastStep.value
        _velovForecastPanel.value = origin?.let { VelovForecastMapPanel.at(it, step) }
        if (origin == null || step == 0) {
            _velovForecastMarkers.value = null
            return
        }
        // La même liste et la même heure tant que le curseur glisse : le service garde les échéances déjà vues.
        val stations = _velovStations.value
        val filter = velovFilter
        scope.launch {
            // Null : le curseur a continué de glisser, la carte garde ce qu'elle montre et la réponse à la
            // dernière demande suit. Les demandes ne sont pas annulées, pour que la carte change en chemin.
            val markers = forecastOrNull { velovForecastService.markers(stations, origin, step, filter) } ?: return@launch
            // Le curseur a pu revenir à « Maintenant » pendant le calcul.
            if (_velovForecastStep.value > 0) _velovForecastMarkers.value = markers
        }
    }

    /** Le résultat d'un calcul de prévision, ou null s'il échoue : pas de prévision plutôt qu'une application qui tombe. */
    private suspend fun <T> forecastOrNull(work: suspend () -> T): T? = try {
        work()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        AppLogger.error("Prévision Vélo'v en échec", e)
        null
    }

    fun dispose() { scope.cancel() }
}
