package com.alertetcl.shared.services

import com.alertetcl.shared.network.HttpClientProvider
import io.ktor.client.call.body
import io.ktor.client.plugins.timeout
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable

/**
 * Recherche des photos de véhicules sur Wikimedia Commons (CC-BY-SA).
 * API publique, sans clé. Politique d'usage : https://www.mediawiki.org/wiki/API:Etiquette
 */
class WikimediaService {
    private val client = HttpClientProvider.client
    private val baseURL = "https://commons.wikimedia.org/w/api.php"

    private val mutex = Mutex()
    private val cache = mutableMapOf<String, List<String>>()

    /** Retourne les URLs de thumbnails (400 px) pour le modèle donné, triées par index. */
    suspend fun fetchPhotoUrls(model: String): List<String> {
        mutex.withLock { cache[model] }?.let { return it }
        val query = "$model TCL"
        return try {
            val resp = client.get(baseURL) {
                url {
                    parameters.append("action", "query")
                    parameters.append("generator", "search")
                    parameters.append("gsrnamespace", "6")
                    parameters.append("gsrsearch", query)
                    parameters.append("gsrlimit", "8")
                    parameters.append("prop", "imageinfo")
                    parameters.append("iiprop", "url")
                    parameters.append("iiurlwidth", "400")
                    parameters.append("format", "json")
                }
                header("User-Agent", "AlerteTCL/1.0 (Android; contact@alertetcl.fr)")
                timeout { requestTimeoutMillis = 8_000L }
            }
            if (resp.status != HttpStatusCode.OK) return emptyList()
            val result = resp.body<WikimediaResponse>()
            val urls = result.query?.pages?.values
                ?.sortedBy { it.index ?: Int.MAX_VALUE }
                ?.mapNotNull { it.imageinfo?.firstOrNull()?.thumburl }
                ?: emptyList()
            mutex.withLock { cache[model] = urls }
            urls
        } catch (_: Throwable) {
            emptyList()
        }
    }

    // MARK: - DTOs

    @Serializable
    private data class WikimediaResponse(val query: WikimediaQuery? = null)

    @Serializable
    private data class WikimediaQuery(val pages: Map<String, WikimediaPage>? = null)

    @Serializable
    private data class WikimediaPage(
        val index: Int? = null,
        val imageinfo: List<WikimediaImageInfo>? = null
    )

    @Serializable
    private data class WikimediaImageInfo(val thumburl: String? = null)

    companion object { val shared = WikimediaService() }
}
