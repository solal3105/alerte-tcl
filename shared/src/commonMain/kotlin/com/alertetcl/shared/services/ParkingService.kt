package com.alertetcl.shared.services

import com.alertetcl.shared.geo.GeoRegion
import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.Parking
import com.alertetcl.shared.models.ParkingState
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.dto.ParkingFeature
import com.alertetcl.shared.network.dto.ParkingResponse
import com.alertetcl.shared.network.safeDecode
import com.alertetcl.shared.network.safeRequest
import com.alertetcl.shared.util.AppLogger
import com.alertetcl.shared.util.SpatialTileCache
import com.alertetcl.shared.util.TileCacheConfig
import com.alertetcl.shared.util.parseIsoEpoch
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

class ParkingService {
    private val baseURL = "https://data.grandlyon.com/geoserver/ogc/features/v1/collections"
    private val client = HttpClientProvider.client

    private val mutex = Mutex()
    private val simpleCache = mutableMapOf<ParkingType, Pair<List<Parking>, Long>>()
    private val simpleCacheValiditySeconds = 30L

    private val bikeTileCache = SpatialTileCache<Parking>(TileCacheConfig.STATIC_DATA)
    private val motoTileCache = SpatialTileCache<Parking>(TileCacheConfig.STATIC_DATA)

    private fun collectionName(type: ParkingType) = when (type) {
        ParkingType.CAR ->
            "metropole-de-lyon:parkings-de-la-metropole-de-lyon-disponibilites-temps-reel-v2"
        ParkingType.BIKE ->
            "metropole-de-lyon:pvo_patrimoine_voirie.pvostationnementvelo"
        ParkingType.MOTORIZED_2W ->
            "ville-de-lyon:vdl_deplacements.emplacement_moto"
    }

    suspend fun fetchParkings(type: ParkingType, forceRefresh: Boolean = false): List<Parking> {
        if (!forceRefresh) {
            mutex.withLock { simpleCache[type] }?.let { (parkings, ts) ->
                val age = Clock.System.now().epochSeconds - ts
                if (age < simpleCacheValiditySeconds) {
                    AppLogger.debug("ParkingService cache hit ${type.displayName}")
                    return parkings
                }
            }
        }
        val (parkings, _) = fetchPage(type, bbox = null, limit = null, startIndex = 0)
        mutex.withLock { simpleCache[type] = parkings to Clock.System.now().epochSeconds }
        return parkings
    }

    suspend fun fetchParkingsInRegion(type: ParkingType, region: GeoRegion, forceRefresh: Boolean = false): List<Parking> {
        if (type == ParkingType.CAR) return fetchParkings(type, forceRefresh)

        val tileCache = if (type == ParkingType.BIKE) bikeTileCache else motoTileCache
        // Pull-to-refresh : invalider les tuiles pour forcer un vrai re-fetch
        if (forceRefresh) tileCache.clear()
        tileCache.pruneExpired()

        val (cached, missing) = tileCache.getItemsForBoundingBox(
            region.minLatitude, region.minLongitude,
            region.maxLatitude, region.maxLongitude
        )
        if (missing.isEmpty()) return cached

        // Pagination obligatoire : GeoServer plafonne à PAGE_LIMIT features par page
        val bbox = tileCache.bboxStringFor(missing)
        val newParkings = mutableListOf<Parking>()
        var startIndex = 0
        var pageFeatureCount: Int
        do {
            val (pageParkings, featureCount) = fetchPage(type, bbox = bbox, limit = PAGE_LIMIT, startIndex = startIndex)
            newParkings += pageParkings
            pageFeatureCount = featureCount
            startIndex += featureCount
        } while (pageFeatureCount == PAGE_LIMIT)

        // Distribute new parkings to their tiles
        val tileSize = TileCacheConfig.STATIC_DATA.tileSizeDegrees
        for (tile in missing) {
            val tileMinLon = tile.x * tileSize
            val tileMaxLon = (tile.x + 1) * tileSize
            val tileMinLat = tile.y * tileSize
            val tileMaxLat = (tile.y + 1) * tileSize
            val items = newParkings.filter {
                it.longitude in tileMinLon..tileMaxLon &&
                it.latitude  in tileMinLat..tileMaxLat
            }
            tileCache.set(tile, items)
        }

        val seen = mutableSetOf<String>()
        val all = mutableListOf<Parking>()
        (cached + newParkings).forEach { if (seen.add(it.id)) all += it }
        return all
    }

    /**
     * Récupère une page. Renvoie les parkings décodés et le nombre brut de features reçues :
     * la pagination doit se baser sur ce dernier, certaines features pouvant être ignorées au décodage.
     */
    private suspend fun fetchPage(
        type: ParkingType,
        bbox: String?,
        limit: Int?,
        startIndex: Int
    ): Pair<List<Parking>, Int> {
        val sb = StringBuilder("$baseURL/${collectionName(type)}/items?f=application/json&sortby=gid")
        if (!bbox.isNullOrEmpty()) sb.append("&bbox=$bbox")
        if (limit != null) sb.append("&limit=$limit")
        if (startIndex > 0) sb.append("&startIndex=$startIndex")

        val response: HttpResponse = safeRequest {
            client.get(sb.toString()) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
        }

        if (response.status != HttpStatusCode.OK)
            throw ApiError.HttpError(response.status.value)

        val body: ParkingResponse = safeDecode { response.body() }

        return body.features.mapNotNull { decodeParking(it, type) } to body.features.size
    }

    private fun decodeParking(feature: ParkingFeature, type: ParkingType): Parking? {
        val coord = feature.geometry?.coordinates ?: return null
        if (coord.size < 2) return null
        val p = feature.properties
        val gid = p.gid ?: return null
        val capacity = when (type) {
            ParkingType.CAR          -> p.nb_places ?: 0
            ParkingType.BIKE         -> p.capacite ?: ((p.nbarceaux ?: 0) * 2)
            ParkingType.MOTORIZED_2W -> p.longueur?.toInt() ?: 0
        }
        val avail = if (type == ParkingType.CAR) (p.places_disponibles ?: 0) else capacity
        val state = if (type == ParkingType.CAR) ParkingState.parse(p.etat) else ParkingState.OUVERT
        val isRealtime = true
        val rawId = "${type.iconKey}-$gid"
        return Parking(
            id = rawId,
            gid = gid,
            nom = p.nom ?: "Parking",
            gestionnaire = p.gestionnaire ?: "",
            adresse = p.adresse ?: "",
            latitude = coord[1],
            longitude = coord[0],
            capaciteTotale = capacity,
            placesDisponibles = avail,
            etat = state,
            lastUpdateEpoch = parseIsoEpoch(p.date_maj),
            parkingType = type,
            isParcRelais = false,
            hasRealtimeData = isRealtime,
            url = p.url,
            hauteurMax = p.hauteur_max,
            nbPmr = p.nb_pmr,
            nbVoituresElectriques = p.nb_voi_elec,
            nbVelo = p.nb_velo,
            nb2Rm = p.nb_2rm,
            nbAutopartage = p.nb_autopartage,
            tarif1h = p.tarif_1h, tarif2h = p.tarif_2h, tarif3h = p.tarif_3h,
            tarif4h = p.tarif_4h, tarif24h = p.tarif_24h,
            aboResident = p.abo_resident, aboNonResident = p.abo_non_resident
        )
    }

    companion object {
        /** Limite de features par page côté GeoServer. */
        private const val PAGE_LIMIT = 1000

        val shared = ParkingService()
    }
}
