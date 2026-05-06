package com.alertetcl.shared.viewmodels

import com.alertetcl.shared.models.Travaux
import com.alertetcl.shared.services.TravauxService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TravauxViewModel(
    private val service: TravauxService = TravauxService.shared
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _travaux = MutableStateFlow<List<Travaux>>(emptyList())
    val travaux: StateFlow<List<Travaux>> = _travaux.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun refresh(force: Boolean = false) {
        scope.launch {
            _isLoading.value = true
            try {
                _travaux.value = service.fetchTravaux(force)
                _errorMessage.value = null
            } catch (e: Throwable) {
                AppLogger.error("TravauxViewModel error", e)
                _errorMessage.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun dispose() { scope.cancel() }
}
