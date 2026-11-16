package com.alertetcl.shared.services

import com.alertetcl.shared.models.VelovForecast
import com.alertetcl.shared.models.VelovForecastBundle
import com.alertetcl.shared.models.VelovForecastFreshness
import com.alertetcl.shared.models.VelovForecastIndex
import com.alertetcl.shared.models.VelovForecastModel
import com.alertetcl.shared.models.VelovForecastReceipt
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.network.ApiError
import com.alertetcl.shared.network.HttpClientProvider
import com.alertetcl.shared.network.NetworkConfiguration
import com.alertetcl.shared.network.safeDecode
import com.alertetcl.shared.network.safeRequest
import com.alertetcl.shared.platform.readLocalFile
import com.alertetcl.shared.platform.writeLocalFile
import com.alertetcl.shared.util.AppLogger
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

    /** Le modèle en mémoire (null : aucun sur disque) et ce que l'on sait de sa fraîcheur. */
    private class Held(val model: VelovForecastModel?, val receipt: VelovForecastReceipt)

    /**
     * Prévision de [station] à partir de son état relevé à [nowEpochMs], ou null s'il ne faut rien
     * afficher : modèle pas encore téléchargé, plus confirmé par le robot, ou station qu'il ne connaît pas.
     */
    suspend fun forecast(station: VelovStation, nowEpochMs: Long): VelovForecast? = withContext(Dispatchers.Default) {
        val held = held()
        updateInBackground()
        held.model
            ?.takeIf { held.receipt.canShow(nowEpochMs / 1000) && it.knows(station.id) }
            ?.forecast(station, nowEpochMs)
    }

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
