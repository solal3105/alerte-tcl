package com.alertetcl.shared.viewmodels

import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.services.ParcRelaisService
import com.alertetcl.shared.services.ParkingService
import com.alertetcl.shared.util.AppLogger
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

class ParkingViewModel(
    private val parkingService: ParkingService = ParkingService.shared,
    private val parcRelaisService: ParcRelaisService = ParcRelaisService.shared
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _parkings = MutableStateFlow<List<Parking>>(emptyList())
    val parkings: StateFlow<List<Parking>> = _parkings.asStateFlow()

    private val _selectedTypes = MutableStateFlow(setOf(ParkingType.CAR))
    val selectedTypes: StateFlow<Set<ParkingType>> = _selectedTypes.asStateFlow()

    private val _showParcRelais = MutableStateFlow(true)
    val showParcRelais: StateFlow<Boolean> = _showParcRelais.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun toggleType(type: ParkingType) {
        val cur = _selectedTypes.value.toMutableSet()
        if (!cur.add(type)) cur.remove(type)
        _selectedTypes.value = cur
    }

    fun toggleParcRelais() {
        _showParcRelais.value = !_showParcRelais.value
    }

    fun loadInRegion(region: GeoRegion, forceRefresh: Boolean = false) {
        scope.launch {
            _isLoading.value = true
            try {
                val carsAsync = if (ParkingType.CAR in _selectedTypes.value)
                    async { parkingService.fetchParkings(ParkingType.CAR, forceRefresh) } else null
                val bikesAsync = if (ParkingType.BIKE in _selectedTypes.value)
                    async { parkingService.fetchParkingsInRegion(ParkingType.BIKE, region, forceRefresh) } else null
                val motoAsync = if (ParkingType.MOTORIZED_2W in _selectedTypes.value)
                    async { parkingService.fetchParkingsInRegion(ParkingType.MOTORIZED_2W, region, forceRefresh) } else null
                val prAsync = if (_showParcRelais.value)
                    async { parcRelaisService.fetchParcRelais(forceRefresh) } else null

                val all = listOfNotNull(
                    carsAsync?.await(),
                    bikesAsync?.await(),
                    motoAsync?.await(),
                    prAsync?.await()
                ).flatten()

                _parkings.value = all
                _errorMessage.value = null
            } catch (e: Throwable) {
                AppLogger.error("ParkingViewModel error", e)
                _errorMessage.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun dispose() { scope.cancel() }
}
