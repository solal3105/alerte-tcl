package com.alertetcl.shared.services

import com.alertetcl.shared.models.NetworkCutsFile
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.safeDecode
import com.alertetcl.shared.network.safeRequest
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

/**
 * Coupures du réseau lues dans les alertes TCL, relayées par le proxy (`/coupures`, relues toutes les
 * 5 minutes sur GitHub, voir coupures/README.md). Un format inconnu est ignoré : une application
 * ancienne ne dessine rien plutôt que de mal lire un fichier qui a changé.
 */
class NetworkCutsService {
    private val client = HttpClientProvider.client
    private val url = NetworkConfiguration.PROXY_BASE_URL + "/coupures"

    private val mutex = Mutex()
    private var cached: NetworkCutsFile? = null
    private var fetchedAtEpoch = 0L

    /** Dernier fichier reçu, sans requête (null avant le premier chargement). */
    val current: NetworkCutsFile? get() = cached

    @Throws(Exception::class)
    suspend fun fetch(): NetworkCutsFile? {
        mutex.withLock {
            if (Clock.System.now().epochSeconds - fetchedAtEpoch < CACHE_SECONDS) return cached
        }
        val response = safeRequest {
            client.get(url) { timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 } }
        }
        if (response.status != HttpStatusCode.OK) throw ApiError.HttpError(response.status.value)
        val file: NetworkCutsFile = safeDecode { response.body() }
        val usable = file.takeIf { it.format == SUPPORTED_FORMAT }
        mutex.withLock {
            cached = usable
            fetchedAtEpoch = Clock.System.now().epochSeconds
        }
        return usable
    }

    companion object {
        const val SUPPORTED_FORMAT = 1
        /** Les applications redemandent au plus toutes les minutes ; le fichier change au plus toutes les 5 minutes. */
        private const val CACHE_SECONDS = 60L
        /** Rythme conseillé aux vues pour relire les coupures pendant que la carte est ouverte. */
        const val REFRESH_INTERVAL_MS = 5 * 60_000L
        val shared = NetworkCutsService()
    }
}
