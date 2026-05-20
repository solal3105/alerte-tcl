package com.alertetcl.shared.viewmodels

import com.alertetcl.shared.models.AnimatedVehicle
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import com.alertetcl.shared.services.SiriLiteService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlin.math.min
import kotlin.math.pow

class LiveVehiclesViewModel(
    private val service: SiriLiteService = SiriLiteService.shared,
    private val pollIntervalMs: Long = 15_000L,
    private val maxIntervalMs: Long  = 60_000L,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _vehicles = MutableStateFlow<List<Vehicle>>(emptyList())
    val vehicles: StateFlow<List<Vehicle>> = _vehicles.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _selectedTypes = MutableStateFlow(VehicleType.entries.toSet())
    val selectedTypes: StateFlow<Set<VehicleType>> = _selectedTypes.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    /** True quand le polling est actif (utilisé par l'indicateur "LIVE"). */
    private val _isLive = MutableStateFlow(false)
    val isLive: StateFlow<Boolean> = _isLive.asStateFlow()

    /** Timestamp epoch-ms du dernier rafraîchissement réussi (pour le countdown). */
    private val _lastUpdateEpochMs = MutableStateFlow<Long?>(null)
    val lastUpdateEpochMs: StateFlow<Long?> = _lastUpdateEpochMs.asStateFlow()

    /** Index des véhicules animés par id (pour interpolation côté UI). */
    private val animatedVehicles = mutableMapOf<String, AnimatedVehicle>()

    private var pollingJob: Job? = null
    private var consecutiveErrors = 0

    /**
     * Intervalle adaptatif : nominal à 15 s (aligné TTL cache Cloudflare),
     * backoff exponentiel sur erreurs consécutives, plafonné à 60 s.
     */
    private val adaptiveIntervalMs: Long
        get() = if (consecutiveErrors == 0) pollIntervalMs
                else min((pollIntervalMs * 1.5.pow(consecutiveErrors.toDouble())).toLong(), maxIntervalMs)

    val filteredVehicles: List<Vehicle>
        get() = _vehicles.value.filter { it.vehicleType in _selectedTypes.value }

    fun toggleType(type: VehicleType) {
        val cur = _selectedTypes.value.toMutableSet()
        if (!cur.add(type)) cur.remove(type)
        _selectedTypes.value = cur
    }

    fun startPolling() {
        if (pollingJob?.isActive == true) return
        _isLive.value = true
        pollingJob = scope.launch {
            while (isActive) {
                val fetchStart = Clock.System.now().toEpochMilliseconds()
                fetchOnce()
                // Cycle net = adaptiveInterval : on soustrait la durée du fetch
                // pour garder un intervalle total stable (parité iOS).
                val fetchDuration = Clock.System.now().toEpochMilliseconds() - fetchStart
                delay(maxOf(adaptiveIntervalMs - fetchDuration, 2_000L))
            }
        }
    }

    fun stopPolling() {
        pollingJob?.cancel()
        pollingJob = null
        _isLive.value = false
        consecutiveErrors = 0
    }

    /** Rafraîchissement manuel depuis l'UI. */
    fun refresh() {
        scope.launch { fetchOnce() }
    }

    private suspend fun fetchOnce() {
        _isLoading.value = true
        try {
            val newList = service.fetchVehicles()
            updateAnimated(newList)
            _errorMessage.value = null
            _lastUpdateEpochMs.value = Clock.System.now().toEpochMilliseconds()
            consecutiveErrors = 0
        } catch (e: Throwable) {
            AppLogger.error("LiveVehiclesViewModel error", e)
            _errorMessage.value = e.message
            consecutiveErrors++
        } finally {
            _isLoading.value = false
        }
    }

    private fun updateAnimated(newList: List<Vehicle>) {
        val nowSec = Clock.System.now().toEpochMilliseconds() / 1000.0
        val newIds = newList.map { it.id }.toHashSet()

        // Mettre à jour ou créer les AnimatedVehicle pour les données fraîches.
        for (v in newList) {
            val existing = animatedVehicles[v.id]
            if (existing == null) animatedVehicles[v.id] = AnimatedVehicle(v)
            else existing.updateWith(v)
        }

        // Supprimer uniquement les véhicules dont la grace period est expirée.
        // Les absents récents (< gracePeriodSeconds) sont conservés pour éviter
        // le clignotement au terminus (changement de trip ID).
        animatedVehicles.entries.removeAll { (id, animated) ->
            id !in newIds && animated.isStale(nowSec)
        }

        // Exposer : véhicules frais + véhicules en grace period.
        val graceVehicles = animatedVehicles.values
            .filter { it.currentVehicle.id !in newIds }
            .map { it.currentVehicle }
        _vehicles.value = newList + graceVehicles
    }

    fun animatedVehicleFor(id: String): AnimatedVehicle? = animatedVehicles[id]

    /** True si au moins un véhicule a une transition d'animation encore active. */
    fun hasAnyActiveTransition(nowSec: Double): Boolean =
        animatedVehicles.values.any { it.hasActiveTransition(nowSec) }

    fun dispose() {
        stopPolling()
        scope.cancel()
    }
}
