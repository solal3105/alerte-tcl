package com.alertetcl.shared.services

import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.models.Passage
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.dto.PassagesResponse
import com.alertetcl.shared.network.dto.StopsResponse
import com.alertetcl.shared.util.AppLogger
import com.alertetcl.shared.util.parsePassageEpoch
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

class TransitStopService {
    private val client = HttpClientProvider.client
    private val stopsEndpoint    = NetworkConfiguration.PROXY_BASE_URL + "/stops"
    private val passagesEndpoint = NetworkConfiguration.PROXY_BASE_URL + "/passages"

    private val mutex = Mutex()
    private var cachedStops = mapOf<Int, TransitStop>()
    private var lastFetchEpoch = 0L
    private val cacheValiditySeconds = 300L

    suspend fun fetchStops(region: GeoRegion? = null): List<TransitStop> {
        val now = Clock.System.now().epochSeconds
        if (now - lastFetchEpoch < cacheValiditySeconds && cachedStops.isNotEmpty()) {
            return cachedStops.values.toList()
        }
        var url = "$stopsEndpoint?f=application/json&limit=10000"
        if (region != null) {
            url += "&bbox=${region.minLongitude},${region.minLatitude},${region.maxLongitude},${region.maxLatitude}"
        }
        val resp = try {
            client.get(url) {
                timeout { requestTimeoutMillis = NetworkConfiguration.HEAVY_TIMEOUT_SECONDS * 1000 }
            }
        } catch (e: Throwable) { throw ApiError.NetworkError(e) }

        if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
        val body: StopsResponse = try { resp.body() } catch (e: Throwable) { throw ApiError.DecodingError(e) }

        val list = body.features.mapNotNull { f ->
            val coords = f.geometry.coordinates
            if (coords.size < 2) return@mapNotNull null
            TransitStop(
                id = f.properties.id,
                nom = f.properties.nom,
                commune = f.properties.commune ?: "",
                adresse = f.properties.adresse,
                latitude = coords[1],
                longitude = coords[0],
                desserte = f.properties.desserte ?: "",
                pmr = f.properties.pmr ?: false
            )
        }
        mutex.withLock {
            cachedStops = list.associateBy { it.id }
            lastFetchEpoch = now
        }
        AppLogger.debug("TransitStopService: ${list.size} arrêts")
        return list
    }

    suspend fun fetchPassagesForStop(stopId: Int): List<Passage> {
        val url = "$passagesEndpoint?id=$stopId&sortby=heurepassage&sortorder=asc"
        val resp = try {
            client.get(url) {
                timeout { requestTimeoutMillis = NetworkConfiguration.HEAVY_TIMEOUT_SECONDS * 1000 }
            }
        } catch (e: Throwable) { throw ApiError.NetworkError(e) }

        if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
        val body: PassagesResponse = try { resp.body() } catch (e: Throwable) { throw ApiError.DecodingError(e) }

        val now = Clock.System.now().epochSeconds
        val passages = body.values
            .filter { v ->
                val ts = parsePassageEpoch(v.heurepassage) ?: return@filter true
                ts >= now
            }
            .map { v ->
                Passage(
                    stopId = v.id,
                    ligne = v.ligne,
                    direction = v.direction,
                    delaipassage = v.delaipassage,
                    heurepassage = v.heurepassage,
                    type = v.type
                )
            }
            .sortedBy { parsePassageEpoch(it.heurepassage) ?: Long.MAX_VALUE }
        return passages
    }

    companion object { val shared = TransitStopService() }
}
