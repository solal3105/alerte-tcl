package com.alertetcl.shared.services

import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingState
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.dto.ParcRelaisRealtimeResponse
import com.alertetcl.shared.network.dto.ParcRelaisStaticResponse
import com.alertetcl.shared.network.safeDecode
import com.alertetcl.shared.network.safeRequest
import com.alertetcl.shared.util.AppLogger
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

class ParcRelaisService {

    private val client = HttpClientProvider.client
    private val staticUrl   = NetworkConfiguration.PROXY_BASE_URL + "/parc-relais?f=application/json&limit=100&sortby=gid"
    private val realtimeUrl = NetworkConfiguration.PROXY_BASE_URL + "/parc-relais-tr?f=application/json&limit=100&sortby=gid"

    private val mutex = Mutex()
    private var cachedStatic: List<Parking>? = null
    private var staticTimestamp = 0L
    private val staticValidity = 86_400L

    private var lastRtTimestamp = 0L
    private val rtValidity = 60L
    private var lastMerged: List<Parking>? = null

    suspend fun fetchParcRelais(forceRefresh: Boolean = false): List<Parking> {
        val now = Clock.System.now().epochSeconds

        val staticList = mutex.withLock {
            val cached = cachedStatic
            if (!forceRefresh && cached != null && now - staticTimestamp < staticValidity) cached else null
        } ?: run {
            val list = fetchStatic()
            mutex.withLock { cachedStatic = list; staticTimestamp = now }
            list
        }

        val needRt = forceRefresh || (now - lastRtTimestamp >= rtValidity)
        if (!needRt) return lastMerged ?: staticList

        // Un échec temps réel ne doit pas écraser les disponibilités connues par des zéros :
        // on conserve la dernière fusion et le prochain appel retentera immédiatement.
        val rtMap = try {
            fetchRealtimeMap()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            AppLogger.warn("ParcRelaisService temps réel indisponible: ${e.message}")
            return lastMerged ?: staticList
        }
        mutex.withLock { lastRtTimestamp = now }

        val merged = staticList.map { pr ->
            val rawId = pr.id.removePrefix("parc-relais-")
            val dispo = rtMap[rawId]
            if (dispo == null) pr else pr.copy(placesDisponibles = dispo, hasRealtimeData = true,
                etat = if (dispo == 0) ParkingState.COMPLET else ParkingState.OUVERT)
        }
        mutex.withLock { lastMerged = merged }
        return merged
    }

    private suspend fun fetchStatic(): List<Parking> = coroutineScope {
        val resp = safeRequest {
            client.get(staticUrl) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
        }
        if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
        val body: ParcRelaisStaticResponse = safeDecode { resp.body() }
        body.features.mapNotNull { f ->
            val firstPoint = f.geometry.coordinates.firstOrNull() ?: return@mapNotNull null
            if (firstPoint.size < 2) return@mapNotNull null
            val coord = LatLng(firstPoint[1], firstPoint[0])
            Parking(
                id = "parc-relais-${f.properties.id}",
                gid = 0,
                nom = f.properties.nom,
                gestionnaire = "TCL",
                adresse = "",
                latitude = coord.latitude,
                longitude = coord.longitude,
                capaciteTotale = f.properties.capacite ?: 0,
                placesDisponibles = 0,
                etat = ParkingState.OUVERT,
                parkingType = ParkingType.CAR,
                isParcRelais = true,
                horaires = f.properties.horaires,
                surveille = f.properties.pSurv,
                hasRealtimeData = false,
                nbPmr = f.properties.placeHandi
            )
        }
    }

    private suspend fun fetchRealtimeMap(): Map<String, Int> {
        val resp = safeRequest {
            client.get(realtimeUrl) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
        }
        if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
        val body: ParcRelaisRealtimeResponse = safeDecode { resp.body() }
        return body.features.mapNotNull { f ->
            val d = f.properties.nbTotPlaceDispo ?: return@mapNotNull null
            f.properties.id to d
        }.toMap()
    }

    companion object { val shared = ParcRelaisService() }
}
