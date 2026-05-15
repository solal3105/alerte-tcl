package com.alertetcl.shared.viewmodels

import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.services.TclApiService
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

class AlertsViewModel(
    private val service: TclApiService = TclApiService.shared,
    private val pollIntervalMs: Long = 60_000L
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _alerts = MutableStateFlow<List<TCLAlert>>(emptyList())
    val alerts: StateFlow<List<TCLAlert>> = _alerts.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _lastUpdate = MutableStateFlow<Long?>(null)
    val lastUpdate: StateFlow<Long?> = _lastUpdate.asStateFlow()

    private var pollingJob: Job? = null

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
                _alerts.value = service.fetchAlerts()
                _lastUpdate.value = Clock.System.now().epochSeconds
                _errorMessage.value = null
            } catch (e: Throwable) {
                AppLogger.error("AlertsViewModel error", e)
                _errorMessage.value = e.message ?: "Erreur"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun dispose() {
        stopPolling()
        scope.cancel()
    }
}
