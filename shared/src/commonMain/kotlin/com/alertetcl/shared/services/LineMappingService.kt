package com.alertetcl.shared.services

import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.util.AppLogger
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock
import kotlinx.serialization.Serializable

/**
 * Charge et met en cache le mapping code opérationnel SIRI → nom commercial TCL.
 * Source : endpoint /line-mapping du proxy (construit depuis code_ligne GeoServer).
 * Exemple : "3082" → "213", "4252" → "C202"
 */
class LineMappingService {
    private val client = HttpClientProvider.client
    private val url = NetworkConfiguration.PROXY_BASE_URL + "/line-mapping"

    private val mutex = Mutex()
    private var cache: Pair<Map<String, String>, Long>? = null
    private val cacheValidity = 86_400L

    suspend fun loadMapping(): Map<String, String> {
        mutex.withLock { cache }?.let { (data, ts) ->
            if (Clock.System.now().epochSeconds - ts < cacheValidity) return data
        }
        return try {
            val resp = client.get(url) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
            if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
            val body: LineMappingResponse = resp.body()
            // Merge static fallbacks pour les lignes absentes de GeoServer
            val mapping = staticFallback + body.mapping
            mutex.withLock { cache = mapping to Clock.System.now().epochSeconds }
            AppLogger.debug("LineMappingService: ${mapping.size} entrées chargées")
            mapping
        } catch (e: Throwable) {
            AppLogger.warn("LineMappingService: impossible de charger le mapping — ${e.message}")
            // Retourne le cache périmé si disponible, sinon map vide
            mutex.withLock { cache }?.first ?: emptyMap()
        }
    }

    companion object {
        val shared = LineMappingService()

        /** Codes absents de GeoServer mais connus — mapping statique de dernier recours. */
        private val staticFallback: Map<String, String> = mapOf(
            "7601" to "N1"   // Navigone N1 (bateau-bus Confluences)
        )
    }
}

@Serializable
private data class LineMappingResponse(val mapping: Map<String, String>)
