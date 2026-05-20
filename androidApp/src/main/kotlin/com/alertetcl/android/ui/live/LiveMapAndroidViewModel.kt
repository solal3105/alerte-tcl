package com.alertetcl.android.ui.live

import androidx.lifecycle.ViewModel
import com.alertetcl.shared.viewmodels.AlertsViewModel
import com.alertetcl.shared.viewmodels.LiveVehiclesViewModel

/**
 * Wrapper AndroidX pour [LiveVehiclesViewModel] (KMP).
 * Survit aux changements de configuration (rotation, changement de langue, etc.).
 * Le scope KMP est détruit proprement via [onCleared].
 */
class LiveMapAndroidViewModel : ViewModel() {
    val vm = LiveVehiclesViewModel()

    override fun onCleared() {
        super.onCleared()
        vm.dispose()
    }
}

/**
 * Wrapper AndroidX pour [AlertsViewModel] (KMP).
 * Même logique que [LiveMapAndroidViewModel].
 */
class AlertsAndroidViewModel : ViewModel() {
    val alertsVm = AlertsViewModel()

    override fun onCleared() {
        super.onCleared()
        alertsVm.dispose()
    }
}
