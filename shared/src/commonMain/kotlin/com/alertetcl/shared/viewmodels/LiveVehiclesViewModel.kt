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

class LiveVehiclesViewModel(
    private val service: SiriLiteService = SiriLiteService.shared,
    private val pollIntervalMs: Long = 15_000L
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

    /** Index des véhicules animés par id (pour interpolation côté UI). */
    private val animatedVehicles = mutableMapOf<String, AnimatedVehicle>()

    private var pollingJob: Job? = null

    val filteredVehicles: List<Vehicle>
        get() = _vehicles.value.filter { it.vehicleType in _selectedTypes.value }

    fun toggleType(type: VehicleType) {
        val cur = _selectedTypes.value.toMutableSet()
        if (!cur.add(type)) cur.remove(type)
        _selectedTypes.value = cur
    }

    fun startPolling() {
        if (pollingJob?.isActive == true) return
        pollingJob = scope.launch {
            while (isActive) {
                refresh()
                delay(pollIntervalMs)
            }
        }
    }

    fun stopPolling() {
        pollingJob?.cancel()
        pollingJob = null
    }

    fun refresh() {
        scope.launch {
            _isLoading.value = true
            try {
                val newList = service.fetchVehicles()
                updateAnimated(newList)
                _vehicles.value = newList
                _errorMessage.value = null
            } catch (e: Throwable) {
                AppLogger.error("LiveVehiclesViewModel error", e)
                _errorMessage.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun updateAnimated(newList: List<Vehicle>) {
        val newIds = newList.map { it.id }.toHashSet()
        // Remove stale
        animatedVehicles.keys.retainAll { it in newIds }
        for (v in newList) {
            val existing = animatedVehicles[v.id]
            if (existing == null) animatedVehicles[v.id] = AnimatedVehicle(v)
            else existing.updateWith(v)
        }
    }

    fun animatedVehicleFor(id: String): AnimatedVehicle? = animatedVehicles[id]

    fun dispose() {
        stopPolling()
        scope.cancel()
    }
}
