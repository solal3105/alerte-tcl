package com.alertetcl.shared.services

import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.models.Travaux
import com.alertetcl.shared.models.TravauxAvancement
import com.alertetcl.shared.models.TravauxImportance
import com.alertetcl.shared.models.TravauxNatureChantier
import com.alertetcl.shared.models.TravauxPerturbation
import com.alertetcl.shared.models.TravauxType
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.dto.TravauxFeature
import com.alertetcl.shared.network.dto.TravauxResponse
import com.alertetcl.shared.util.parseDateEpoch
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.Clock

class TravauxService {
    private val client = HttpClientProvider.client
    private val baseURL =
        "https://data.grandlyon.com/geoserver/ogc/features/v1/collections/metropole-de-lyon:lyv_lyvia.lyvchantier/items"

    private val mutex = Mutex()
    private var cache: Pair<List<Travaux>, Long>? = null
    private val cacheValidity = 300L

    suspend fun fetchTravaux(forceRefresh: Boolean = false): List<Travaux> {
        if (!forceRefresh) {
            mutex.withLock { cache }?.let { (data, ts) ->
                if (Clock.System.now().epochSeconds - ts < cacheValidity) return data
            }
        }

        // limit=2000 couvre le dataset complet (1116 records actuels) en une seule requête.
        val url = "$baseURL?f=application/json&limit=2000"
        val resp = try {
            client.get(url) {
                timeout { requestTimeoutMillis = NetworkConfiguration.SHARED_TIMEOUT_SECONDS * 1000 }
            }
        } catch (e: Throwable) { throw ApiError.NetworkError(e) }
        if (resp.status != HttpStatusCode.OK) throw ApiError.HttpError(resp.status.value)
        val body: TravauxResponse = try { resp.body() } catch (e: Throwable) { throw ApiError.DecodingError(e) }

        val now = Clock.System.now().epochSeconds
        val travaux = body.features.map { decode(it) }.filter { it.isActive(now) }
        mutex.withLock { cache = travaux to now }
        return travaux
    }

    private fun decode(f: TravauxFeature): Travaux {
        val p = f.properties
        val nom = p.adresse ?: p.nom ?: "Rue inconnue"
        val nomChantier = p.natureChantier ?: p.nomchantier ?: "Travaux"
        val commune = p.commune ?: p.commune1 ?: "Lyon"
        val codeInsee = p.codeInsee?.toString() ?: p.insee ?: ""
        val description = p.mesuresPolice ?: p.descripchantierinternet
        val precision = p.natureTravaux ?: p.precisionlocalisation

        // Avancement par état
        val etat = p.etat?.lowercase() ?: ""
        val avancement = when {
            "ouvert" in etat || "en cours" in etat -> TravauxAvancement.EN_COURS
            "termin" in etat -> TravauxAvancement.TERMINE
            else -> TravauxAvancement.parse(p.avancement)
        }

        val importance = TravauxImportance.parse(p.codeimportance)
        val perturbation = TravauxPerturbation.parse(p.typeperturbation)

        // Polygons (normalisés par TravauxGeometry.rings, gère Multi/Polygon/LineString)
        val polygons = mutableListOf<List<LatLng>>()
        val allLats = mutableListOf<Double>()
        val allLons = mutableListOf<Double>()
        for (ring in f.geometry.rings) {
            if (ring.isNotEmpty()) {
                polygons += ring
                ring.forEach { allLats += it.latitude; allLons += it.longitude }
            }
        }
        val centroid = if (allLats.isNotEmpty()) {
            LatLng(allLats.average(), allLons.average())
        } else LatLng(45.764043, 4.835659)

        return Travaux(
            id = f.id,
            nom = nom,
            nomChantier = nomChantier,
            commune = commune,
            codeInsee = codeInsee,
            precisionLocalisation = precision,
            debutEpoch = parseDateEpoch(p.dateDebut ?: p.debutchantier),
            finEpoch = parseDateEpoch(p.dateFin ?: p.finchantier),
            description = description,
            avancement = avancement,
            importance = importance,
            typePerturbation = perturbation,
            intervenant = p.intervenant ?: "Non spécifié",
            polygons = polygons,
            centroid = centroid,
            type = TravauxType.detect(nomChantier),
            natureChantier = TravauxNatureChantier.detect(p.natureChantier)
        )
    }

    companion object { val shared = TravauxService() }
}
