package com.alertetcl.shared.services

import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecastBundle
import com.alertetcl.shared.models.VelovForecastFreshness
import com.alertetcl.shared.models.VelovForecastIndex
import com.alertetcl.shared.models.VelovForecastMarker
import com.alertetcl.shared.models.VelovForecastMarkers
import com.alertetcl.shared.models.VelovForecastModel
import com.alertetcl.shared.models.VelovForecastReceipt
import com.alertetcl.shared.models.VelovForecastSheet
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.safeDecode
import com.alertetcl.shared.network.safeRequest
import com.alertetcl.shared.platform.readLocalFile
import com.alertetcl.shared.platform.writeLocalFile
import com.alertetcl.shared.util.AppLogger
import com.alertetcl.shared.util.LatestOnly
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.datetime.Clock

/**
 * Prévisions de disponibilité des stations Vélo'v, calculées sur l'appareil ([VelovForecastModel]).
 *
 * Le modèle (`/velov-prevision/modele.json`, plusieurs Mo) est gardé sur disque puis en mémoire : une
 * fiche de station n'attend jamais le réseau. Le relais n'est interrogé qu'une fois par jour
 * (`index.json`), en arrière-plan, et le modèle n'est retéléchargé que si sa version a changé. Tant
 * qu'aucun modèle n'est arrivé, ou si le robot ne l'a plus confirmé depuis trop longtemps
 * ([VelovForecastFreshness]), il n'y a pas de prévision. Lecture, décodage et calcul se font hors du
 * fil principal.
 *
 * Partout, `originEpochMs` est l'heure où l'état des stations a été relevé : la fiche et la carte
 * doivent donner la même pour parler des mêmes échéances.
 */
class VelovForecastService {
    private val client = HttpClientProvider.client
    private val json = HttpClientProvider.json
    private val baseUrl = NetworkConfiguration.PROXY_BASE_URL + "/velov-prevision"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /** Protège [held], lu du disque au premier besoin. */
    private val mutex = Mutex()
    private var held: Held? = null

    /** Une seule mise à jour à la fois ; protège [attemptedAt]. */
    private val updateMutex = Mutex()
    private var attemptedAt = 0L

    /** Un seul calcul de marqueurs à la fois (leur mémoire n'est pas faite pour plusieurs fils), le dernier demandé d'abord. */
    private val markersQueue = LatestOnly()

    /** Le modèle en mémoire (null : aucun sur disque), ce que l'on sait de sa fraîcheur, et les marqueurs de carte déjà calculés avec lui. */
    private class Held(val model: VelovForecastModel?, val receipt: VelovForecastReceipt) {
        val markers: VelovForecastMarkers? = model?.let(::VelovForecastMarkers)

        fun usableModel(originEpochMs: Long): VelovForecastModel? = model?.takeIf { receipt.canShow(originEpochMs / 1000) }
    }

    /**
     * Vrai s'il y a des prévisions à montrer : un modèle est arrivé et le robot le confirme encore.
     * C'est la condition d'affichage du curseur d'heure de la carte.
     */
    suspend fun isAvailable(originEpochMs: Long): Boolean = withContext(Dispatchers.Default) {
        current().usableModel(originEpochMs) != null
    }

    /**
     * La prévision de [station] pour sa fiche, ou null s'il ne faut rien afficher : pas de prévision
     * disponible, station fermée, ou que le modèle ne connaît pas. [stations] (toutes celles de la
     * carte) sert à proposer des voisines plus sûres.
     */
    suspend fun sheet(station: VelovStation, stations: List<VelovStation>, originEpochMs: Long): VelovForecastSheet? = withContext(Dispatchers.Default) {
        current().usableModel(originEpochMs)?.let { VelovForecastSheet.of(it, station, stations, originEpochMs) }
    }

    /**
     * Les marqueurs de la carte à l'échéance [step] (1 à 96) pour [filter] : une liste vide sans
     * prévision disponible, et pas de marqueur pour une station fermée ou inconnue du modèle. Une
     * échéance déjà demandée pour les mêmes [stations], la même heure et le même filtre revient aussitôt.
     *
     * Null quand une autre échéance a été demandée entre-temps (le curseur a continué de glisser) :
     * la carte garde alors ce qu'elle montre, la réponse à la dernière demande suit.
     */
    suspend fun markers(stations: List<VelovStation>, originEpochMs: Long, step: Int, filter: VelovFilter): List<VelovForecastMarker>? = withContext(Dispatchers.Default) {
        val held = current()
        val markers = held.markers?.takeIf { held.usableModel(originEpochMs) != null } ?: return@withContext emptyList()
        markersQueue.run { markers.at(stations, originEpochMs, step, filter) }
    }

    /** Le modèle gardé, en demandant au passage sa mise à jour si c'est le moment. */
    private suspend fun current(): Held = held().also { updateInBackground() }

    /**
     * Charge le modèle et demande sa mise à jour sans attendre : à appeler dès que les stations Vélo'v
     * s'affichent, pour que la première fiche ouverte ait déjà sa prévision.
     */
    fun warmUp() {
        updateInBackground()
    }

    private suspend fun held(): Held = mutex.withLock {
        held ?: readFromDisk().also { held = it }
    }

    private fun readFromDisk(): Held {
        val model = readLocalFile(MODEL_FILE)?.let { text ->
            runCatching { decodeModel(text) }
                .onFailure { AppLogger.warn("Prévision Vélo'v : modèle enregistré illisible (${it.message})") }
                .getOrNull()
        }
        val receipt = readLocalFile(RECEIPT_FILE)
            ?.let { text -> runCatching { json.decodeFromString(VelovForecastReceipt.serializer(), text) }.getOrNull() }
            ?: VelovForecastReceipt()
        return Held(model, receipt.matching(model?.version))
    }

    private fun decodeModel(text: String): VelovForecastModel =
        VelovForecastModel(json.decodeFromString(VelovForecastBundle.serializer(), text))

    private fun updateInBackground() {
        scope.launch {
            if (!updateMutex.tryLock()) return@launch
            try {
                update()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                AppLogger.warn("Prévision Vélo'v : mise à jour remise à plus tard (${e.message})")
            } finally {
                updateMutex.unlock()
            }
        }
    }

    /** Demande au relais où en est le modèle, si c'est le moment, et télécharge le nouveau s'il a changé. */
    private suspend fun update() {
        val current = held()
        val now = Clock.System.now().epochSeconds
        if (!VelovForecastFreshness.isCheckDue(current.receipt.checkedAt, attemptedAt, now)) return
        attemptedAt = now

        val indexText = fetchText("$baseUrl/index.json", NetworkConfiguration.SHARED_TIMEOUT_SECONDS)
        val index = safeDecode { json.decodeFromString(VelovForecastIndex.serializer(), indexText) }
        val downloaded = if (current.receipt.isOutdatedBy(index)) download(index, now) else null
        keep(downloaded ?: Held(current.model, current.receipt.answeredBy(index, now)))
    }

    /**
     * Le modèle annoncé par [index], enregistré sur disque ; null s'il est illisible ou si le relais est
     * pris entre deux publications (index de l'une, modèle de l'autre). On ne garde un modèle que sous
     * le contrôle qui porte sur lui, et retélécharger plusieurs Mo tout de suite n'y changerait rien :
     * l'appelant note la demande comme faite, la suivante attendra demain.
     */
    private suspend fun download(index: VelovForecastIndex, now: Long): Held? {
        val text = fetchText("$baseUrl/modele.json", NetworkConfiguration.DOWNLOAD_TIMEOUT_SECONDS)
        val model = runCatching { decodeModel(text) }.getOrNull()?.takeIf { it.version == index.version }
        if (model == null) {
            AppLogger.warn("Prévision Vélo'v : modèle ${index.version} inutilisable pour l'instant")
            return null
        }
        if (!writeLocalFile(MODEL_FILE, text)) AppLogger.warn("Prévision Vélo'v : modèle non enregistré, il sera retéléchargé")
        return Held(model, VelovForecastReceipt(index.version, index.verifiedAt, now))
    }

    private suspend fun keep(fresh: Held) {
        writeLocalFile(RECEIPT_FILE, json.encodeToString(VelovForecastReceipt.serializer(), fresh.receipt))
        mutex.withLock { held = fresh }
    }

    private suspend fun fetchText(url: String, timeoutSeconds: Long): String {
        val response = safeRequest {
            client.get(url) { timeout { requestTimeoutMillis = timeoutSeconds * 1000 } }
        }
        if (response.status != HttpStatusCode.OK) throw ApiError.HttpError(response.status.value)
        return safeRequest { response.bodyAsText() }
    }

    companion object {
        private const val MODEL_FILE = "velov-prevision-modele.json"
        private const val RECEIPT_FILE = "velov-prevision-recu.json"
        val shared = VelovForecastService()
    }
}
