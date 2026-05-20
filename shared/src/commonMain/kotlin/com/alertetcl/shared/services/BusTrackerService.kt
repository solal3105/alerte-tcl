package com.alertetcl.shared.services

import com.alertetcl.shared.network.HttpClientProvider
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable

/**
 * Récupère les informations de véhicule depuis l'API publique Bus Tracker.
 * Source externe non officielle — données manquantes ou erreurs silencieusement ignorées.
 * Référence : https://bus-tracker.fr
 */
class BusTrackerService {
    private val client = HttpClientProvider.client
    private val baseURL = "https://bus-tracker.fr/api/vehicles"
    private val networkId = 91 // TCL Lyon (id stable dans la DB Bus Tracker)

    private val mutex = Mutex()
    private val cache = mutableMapOf<String, String>()

    /** Retourne la désignation (modèle) du véhicule, ou null si non trouvé / erreur. */
    suspend fun fetchVehicleModel(fleetNumber: String): String? {
        mutex.withLock { cache[fleetNumber] }?.let { return it }
        return try {
            val resp = client.get("$baseURL?networkId=$networkId&number=$fleetNumber") {
                timeout { requestTimeoutMillis = 8_000L }
            }
            if (resp.status != HttpStatusCode.OK) return null
            val vehicles: List<BusTrackerVehicleDto> = resp.body()
            val designation = vehicles.firstOrNull { it.number == fleetNumber }?.designation ?: return null
            mutex.withLock { cache[fleetNumber] = designation }
            designation
        } catch (_: Throwable) {
            null
        }
    }

    @Serializable
    private data class BusTrackerVehicleDto(val number: String? = null, val designation: String? = null)

    companion object { val shared = BusTrackerService() }
}
