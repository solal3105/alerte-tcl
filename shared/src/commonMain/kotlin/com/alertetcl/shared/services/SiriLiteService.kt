package com.alertetcl.shared.services

import com.alertetcl.shared.models.StopInfo
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.dto.MonitoredCallDto
import com.alertetcl.shared.network.dto.SIRIResponse
import com.alertetcl.shared.util.AppLogger
import com.alertetcl.shared.util.parseDurationSeconds
import com.alertetcl.shared.util.parseIsoEpoch
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpStatusCode

/**
 * Service de chargement des véhicules SIRI Lite (positions temps réel).
 * Le proxy convertit le XML SIRI en JSON.
 */
class SiriLiteService {

    private val endpoint = NetworkConfiguration.PROXY_BASE_URL + "/vehicles"
    private val client = HttpClientProvider.client

    /** Provider de noms d'arrêts GTFS — chargé via le bundle natif. */
    var stopNameLookup: (String) -> String? = { null }

    private val lineNameRegex    = Regex("::([^:]+):SYTRAL")
    private val metroRegex        = Regex("^M[A-D]$")
    private val tramRegex         = Regex("^T\\d+$")
    private val trolleyRegex      = Regex("^TB\\d+$")
    private val funicularRegex    = Regex("^F\\d*$")

    suspend fun fetchVehicles(): List<Vehicle> {
        val response: HttpResponse = try {
            client.get(endpoint) {
                timeout { requestTimeoutMillis = NetworkConfiguration.FAST_TIMEOUT_SECONDS * 1000 }
            }
        } catch (e: Throwable) {
            throw ApiError.NetworkError(e)
        }

        if (response.status != HttpStatusCode.OK) {
            throw ApiError.HttpError(response.status.value)
        }

        val body: SIRIResponse = try {
            response.body()
        } catch (e: Throwable) {
            throw ApiError.DecodingError(e)
        }

        return parseVehicles(body)
    }

    private fun parseVehicles(siri: SIRIResponse): List<Vehicle> {
        val delivery = siri.Siri.ServiceDelivery.VehicleMonitoringDelivery?.firstOrNull()
        val activities = delivery?.VehicleActivity ?: return emptyList()

        if (delivery.MoreData == true) {
            AppLogger.warn("⚠️ MoreData=true — réponse tronquée, augmenter MaximumVehicles ou paginer")
        }

        return activities.mapNotNull { activity ->
            val journey = activity.MonitoredVehicleJourney ?: return@mapNotNull null
            val location = journey.VehicleLocation ?: return@mapNotNull null
            val lat = location.Latitude ?: return@mapNotNull null
            val lon = location.Longitude ?: return@mapNotNull null
            val monRef = activity.VehicleMonitoringRef?.value
            val vehRef = journey.VehicleRef?.value
            val vehicleId = if (!vehRef.isNullOrEmpty()) vehRef else (monRef ?: return@mapNotNull null)
            if (vehicleId.isEmpty()) return@mapNotNull null

            val lineRef = journey.LineRef?.value ?: ""
            val lineName = extractLineName(lineRef)
            val type = detectVehicleType(lineName)
            val destination = extractDestination(journey.DestinationRef?.value)
            val direction = journey.DirectionRef?.value?.trim()?.uppercase() ?: ""
            val delay = parseDurationSeconds(journey.Delay)
            val nextStop = parseMonitoredCall(journey.MonitoredCall)

            Vehicle(
                id = vehicleId,
                latitude = lat,
                longitude = lon,
                bearing = journey.Bearing ?: 0.0,
                lineRef = lineRef,
                lineName = lineName,
                vehicleType = type,
                destination = destination,
                direction = direction,
                delay = delay,
                status = journey.VehicleStatus,
                recordedAtEpoch = parseIsoEpoch(activity.RecordedAtTime),
                validUntilEpoch = parseIsoEpoch(activity.ValidUntilTime),
                nextStop = nextStop
            )
        }
    }

    private fun parseMonitoredCall(c: MonitoredCallDto?): StopInfo? {
        val ref = c?.StopPointRef?.value ?: return null
        // MonitoredCall = dernier arrêt surveillé, pas forcément le prochain.
        // Si le bus a déjà quitté cet arrêt, on ne l'affiche pas.
        if (c.DepartureStatus == "departed") return null
        return StopInfo(
            id = ref,
            stopRef = ref,
            stopName = extractStopName(ref),
            aimedArrivalTimeEpoch = parseIsoEpoch(c.AimedArrivalTime),
            aimedDepartureTimeEpoch = parseIsoEpoch(c.AimedDepartureTime),
            distanceFromStop = c.DistanceFromStop,
            order = c.Order
        )
    }

    private fun extractStopName(stopRef: String): String? {
        // Format: "ActIV:StopArea:SP:39975:SYTRAL"
        val parts = stopRef.split(":")
        if (parts.size < 4) return parts.lastOrNull() ?: stopRef
        val numericId = parts[3]
        return stopNameLookup(numericId) ?: numericId
    }

    private fun extractLineName(ref: String): String {
        if (ref.isEmpty()) return "?"
        val match = lineNameRegex.find(ref)
        if (match != null) return match.groupValues[1]
        return ref.split(":").lastOrNull() ?: ref
    }

    private fun detectVehicleType(lineName: String): VehicleType {
        val u = lineName.uppercase()
        return when {
            metroRegex.matches(u) -> VehicleType.METRO
            tramRegex.matches(u)  -> VehicleType.TRAM
            u == "RHONEXPRESS" || u == "RX" -> VehicleType.TRAM
            trolleyRegex.matches(u)   -> VehicleType.TROLLEY
            funicularRegex.matches(u) -> VehicleType.FUNICULAR
            else -> VehicleType.BUS
        }
    }

    private fun extractDestination(ref: String?): String {
        if (ref.isNullOrEmpty()) return ""
        // Format DestinationRef : "ActIV:StopArea:SP:39975:SYTRAL" — identique aux StopPointRef
        val parts = ref.split(":")
        if (parts.size < 4) return ""
        val numericId = parts[3]
        return stopNameLookup(numericId) ?: ""
    }

    companion object { val shared = SiriLiteService() }
}
