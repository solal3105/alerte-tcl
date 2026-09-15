package com.alertetcl.shared.services

import com.alertetcl.shared.models.DirectionMatching
import com.alertetcl.shared.models.LinePalette
import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.TimetableIndex
import com.alertetcl.shared.models.TimetableKeys
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
 * Fiches horaires théoriques servies par le proxy (/horaires/...), cf. horaires/README.md.
 * L'index est rafraîchi toutes les heures ; les fiches de ligne sont gardées en mémoire tant
 * que l'index ne change pas de génération.
 */
class TimetableService {
    private val client = HttpClientProvider.client
    private val baseUrl = NetworkConfiguration.PROXY_BASE_URL + "/horaires"

    private val mutex = Mutex()
    private var cachedIndex: TimetableIndex? = null
    private var indexFetchedAt = 0L
    private val lineCache = mutableMapOf<String, LineTimetable>()

    @Throws(Exception::class)
    suspend fun fetchIndex(): TimetableIndex {
        mutex.withLock {
            val cached = cachedIndex
            if (cached != null && Clock.System.now().epochSeconds - indexFetchedAt < INDEX_VALIDITY_SECONDS) return cached
        }
        val index: TimetableIndex = fetchJson("$baseUrl/index.json")
        LinePalette.apply(index)
        mutex.withLock {
            if (cachedIndex?.generatedAt != index.generatedAt) lineCache.clear()
            cachedIndex = index
            indexFetchedAt = Clock.System.now().epochSeconds
        }
        return index
    }

    /** Fiche d'une ligne dans un sens ("A" / "R"). [ApiError.NotFound] si la ligne n'a pas de fiche. */
    @Throws(Exception::class)
    suspend fun fetchLine(line: String, direction: String): LineTimetable {
        val key = TimetableKeys.keyFor(line)
        val cacheKey = "$key|$direction"
        mutex.withLock { lineCache[cacheKey] }?.let { return it }
        val timetable: LineTimetable = fetchJson("$baseUrl/lignes/$key/$direction.json")
        mutex.withLock { lineCache[cacheKey] = timetable }
        return timetable
    }

    /**
     * Fiche correspondant à une carte « ligne + destination » de la fiche d'un arrêt.
     * Le sens est déduit des terminus GeoServer, sinon du nom de destination de l'index,
     * sinon de l'arrêt lui-même (le sens qui le dessert). Null si la ligne n'a pas de fiche.
     */
    /** Variante Swift : identifiants d'arrêts en liste. */
    @Throws(Exception::class)
    suspend fun findForStopIds(
        line: String,
        destination: String,
        stopIds: List<Int>,
        stopName: String,
        termini: Map<String, String>
    ): LineTimetable? = findForStop(line, destination, stopIds.toSet(), stopName, termini)

    @Throws(Exception::class)
    suspend fun findForStop(
        line: String,
        destination: String,
        stopIds: Set<Int>,
        stopName: String,
        termini: Map<String, String>
    ): LineTimetable? {
        val summary = fetchIndex().line(line) ?: return null
        val available = summary.directions.map { it.dir }
        if (available.isEmpty()) return null

        DirectionMatching.resolveDirection(line, destination, termini)
            ?.takeIf { it in available }
            ?.let { return fetchLine(summary.line, it) }

        summary.directions.singleOrNull { DirectionMatching.namesMatch(it.headsign, destination) }
            ?.let { return fetchLine(summary.line, it.dir) }

        if (available.size == 1) return fetchLine(summary.line, available[0])

        val candidates = available.map { fetchLine(summary.line, it) }
        return candidates.firstOrNull { it.stopIndexes(stopIds, stopName).isNotEmpty() } ?: candidates.first()
    }

    private suspend inline fun <reified T> fetchJson(url: String): T {
        val resp = safeRequest {
            client.get(url) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
        }
        when (resp.status) {
            HttpStatusCode.OK -> Unit
            HttpStatusCode.NotFound -> throw ApiError.NotFound
            else -> throw ApiError.HttpError(resp.status.value)
        }
        return safeDecode { resp.body() }
    }

    companion object {
        private const val INDEX_VALIDITY_SECONDS = 3600L
        val shared = TimetableService()
    }
}
