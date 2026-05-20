package com.alertetcl.shared.services

import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.dto.AlertsApiResponse
import com.alertetcl.shared.util.AppLogger
import com.alertetcl.shared.util.parseIsoEpoch
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpStatusCode
import kotlinx.datetime.Clock

/**
 * Service de chargement des alertes trafic TCL via le proxy Cloudflare.
 */
class TclApiService {

    private val endpoint = NetworkConfiguration.PROXY_BASE_URL + "/alerts"
    private val client = HttpClientProvider.client

    suspend fun fetchAlerts(): List<TCLAlert> {
        val response: HttpResponse = try {
            client.get(endpoint) {
                timeout { requestTimeoutMillis = NetworkConfiguration.FAST_TIMEOUT_SECONDS * 1000 }
            }
        } catch (e: Throwable) {
            AppLogger.error("TclApiService: erreur réseau", e)
            throw ApiError.NetworkError(e)
        }

        when (response.status) {
            HttpStatusCode.OK -> { /* continue */ }
            HttpStatusCode.Unauthorized -> throw ApiError.Unauthorized
            else -> throw ApiError.HttpError(response.status.value)
        }

        val body: AlertsApiResponse = try {
            response.body()
        } catch (e: Throwable) {
            throw ApiError.DecodingError(e)
        }

        val now = Clock.System.now().epochSeconds
        val alerts = body.values.mapNotNull { dto ->
            val id = "${dto.n ?: 0}-${dto.ligneCom.orEmpty()}-${dto.ligneCli.orEmpty()}"
            TCLAlert(
                id = id,
                type = dto.type ?: "Information",
                cause = dto.cause ?: "",
                debutEpoch = parseIsoEpoch(dto.debut),
                finEpoch = parseIsoEpoch(dto.fin),
                mode = TransportMode.fromString(dto.mode),
                ligneCom = dto.ligneCom ?: "",
                ligneCli = dto.ligneCli ?: "",
                titre = dto.titre ?: "",
                message = dto.message ?: "",
                niveauSeverite = dto.niveauSeverite
            )
        }.filter { it.isActive(now) }

        AppLogger.debug("TclApiService: ${alerts.size} alertes actives")
        return alerts
    }

    companion object { val shared = TclApiService() }
}
