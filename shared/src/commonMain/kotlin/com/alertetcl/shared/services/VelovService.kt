package com.alertetcl.shared.services

import com.alertetcl.shared.models.VelovResponse
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.safeDecode
import com.alertetcl.shared.network.safeRequest
import com.alertetcl.shared.util.DemoShowcase
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

/** Stations Vélo'v avec leur disponibilité, relayées par le proxy (`/velov`, rafraîchi toutes les minutes). */
class VelovService {
    private val client = HttpClientProvider.client
    private val url = NetworkConfiguration.PROXY_BASE_URL + "/velov"

    private val mutex = Mutex()
    private var cached: List<VelovStation>? = null
    private var fetchedAtEpoch = 0L

    @Throws(Exception::class)
    suspend fun fetchStations(forceRefresh: Boolean = false): List<VelovStation> {
        if (DemoShowcase.isActive) return DemoShowcase.velovStations()
        if (!forceRefresh) {
            mutex.withLock {
                val stations = cached
                if (stations != null && Clock.System.now().epochSeconds - fetchedAtEpoch < CACHE_SECONDS) return stations
            }
        }
        val response = safeRequest {
            client.get(url) { timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 } }
        }
        if (response.status != HttpStatusCode.OK) throw ApiError.HttpError(response.status.value)
        val body: VelovResponse = safeDecode { response.body() }
        mutex.withLock {
            cached = body.stations
            fetchedAtEpoch = Clock.System.now().epochSeconds
        }
        return body.stations
    }

    companion object {
        private const val CACHE_SECONDS = 60L
        val shared = VelovService()
    }
}
