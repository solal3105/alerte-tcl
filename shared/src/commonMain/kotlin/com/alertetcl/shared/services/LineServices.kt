package com.alertetcl.shared.services

import com.alertetcl.shared.models.BusLine
import com.alertetcl.shared.models.TransitLine
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.dto.BusLineResponse
import com.alertetcl.shared.network.dto.TransitLineResponse
import com.alertetcl.shared.util.AppLogger
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

class BusLineService {
    private val client = HttpClientProvider.client
    private val baseURL = NetworkConfiguration.PROXY_BASE_URL + "/bus-lines"

    private val mutex = Mutex()
    private var cache: Pair<List<BusLine>, Long>? = null
    private val cacheValidity = 86_400L

    suspend fun fetchBusLines(): List<BusLine> {
        mutex.withLock { cache }?.let { (data, ts) ->
            if (Clock.System.now().epochSeconds - ts < cacheValidity) return data
        }
        val url = "$baseURL?limit=1000&f=json"
        val resp = try {
            client.get(url) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
        } catch (e: Throwable) { throw ApiError.NetworkError(e) }
        if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
        val body: BusLineResponse = try { resp.body() } catch (e: Throwable) { throw ApiError.DecodingError(e) }

        val lines = mutableListOf<BusLine>()
        for (feature in body.features) {
            val name = feature.properties.ligne ?: continue
            feature.geometry.coordinates.forEachIndexed { idx, segment ->
                if (segment.isNotEmpty()) {
                    lines += BusLine(id = "${feature.id}_$idx", name = name, coordinates = segment)
                }
            }
        }
        mutex.withLock { cache = lines to Clock.System.now().epochSeconds }
        AppLogger.debug("BusLineService: ${lines.size} segments")
        return lines
    }

    companion object { val shared = BusLineService() }
}

class TransitLineService {
    private val client = HttpClientProvider.client
    private val metroFuniUrl = NetworkConfiguration.PROXY_BASE_URL + "/metro-funi-lines"
    private val tramUrl      = NetworkConfiguration.PROXY_BASE_URL + "/tram-lines"

    private val mutex = Mutex()
    private var cache: Pair<List<TransitLine>, Long>? = null
    private val cacheValidity = 86_400L

    /** Provider de fallback chargé depuis bundle natif (JSON). */
    var bundledFallback: () -> List<TransitLine> = { emptyList() }

    suspend fun fetchTransitLines(): List<TransitLine> {
        mutex.withLock { cache }?.let { (data, ts) ->
            if (Clock.System.now().epochSeconds - ts < cacheValidity) return data
        }
        return try {
            coroutineScope {
                val mAsync = async { fetchSection(metroFuniUrl, "métro/funi") }
                val tAsync = async { fetchSection(tramUrl, "tram") }
                val all = mAsync.await() + tAsync.await()
                mutex.withLock { cache = all to Clock.System.now().epochSeconds }
                all
            }
        } catch (e: Throwable) {
            AppLogger.warn("TransitLineService fallback bundle: ${e.message}")
            val fallback = bundledFallback()
            mutex.withLock { cache = fallback to Clock.System.now().epochSeconds }
            fallback
        }
    }

    private suspend fun fetchSection(url: String, label: String): List<TransitLine> {
        val full = "$url?limit=30&f=json"
        val resp = try {
            client.get(full) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
        } catch (e: Throwable) { throw ApiError.NetworkError(e) }
        if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
        val body: TransitLineResponse = try { resp.body() } catch (e: Throwable) { throw ApiError.DecodingError(e) }

        val lines = mutableListOf<TransitLine>()
        for (feature in body.features) {
            val name = feature.properties.ligne ?: continue
            val family = feature.properties.familleTransport ?: continue
            feature.geometry.coordinates.forEachIndexed { idx, segment ->
                if (segment.isNotEmpty()) {
                    lines += TransitLine(
                        id = "${feature.id}_$idx",
                        name = name,
                        coordinates = segment,
                        familyTransport = family
                    )
                }
            }
        }
        return lines
    }

    companion object { val shared = TransitLineService() }
}
