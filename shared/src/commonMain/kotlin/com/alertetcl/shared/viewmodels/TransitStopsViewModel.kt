package com.alertetcl.shared.viewmodels

import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.services.TransitStopService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TransitStopsViewModel(
    private val service: TransitStopService = TransitStopService.shared
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _stops = MutableStateFlow<List<TransitStop>>(emptyList())
    val stops: StateFlow<List<TransitStop>> = _stops.asStateFlow()

    private val _passagesByStop = MutableStateFlow<Map<Int, List<Passage>>>(emptyMap())
    val passagesByStop: StateFlow<Map<Int, List<Passage>>> = _passagesByStop.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun loadStops(region: GeoRegion? = null) {
        scope.launch {
            _isLoading.value = true
            try {
                _stops.value = service.fetchStops(region)
            } catch (e: Throwable) {
                AppLogger.error("TransitStopsViewModel error", e)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun loadPassages(stopId: Int) {
        scope.launch {
            try {
                val list = service.fetchPassagesForStop(stopId)
                _passagesByStop.value = _passagesByStop.value + (stopId to list)
            } catch (e: Throwable) {
                AppLogger.error("TransitStopsViewModel passages error", e)
            }
        }
    }

    fun dispose() { scope.cancel() }
}
