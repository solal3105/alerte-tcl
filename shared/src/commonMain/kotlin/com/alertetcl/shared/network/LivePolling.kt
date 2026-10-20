package com.alertetcl.shared.network

import kotlin.math.min
import kotlin.math.pow
import kotlin.random.Random

/**
 * Rythme de rafraîchissement des positions des véhicules.
 *
 * Le relais ne va chercher les positions qu'après chaque vague publiée par Grand Lyon
 * (environ toutes les 30 s, à des instants irréguliers) et annonce dans l'en-tête
 * [REFRESH_IN_HEADER] dans combien de millisecondes sa copie suivante sera prête.
 * L'application redemande juste après, avec un écart aléatoire d'au plus [MAX_SPREAD_MS]
 * pour que les téléphones n'arrivent pas tous à la même milliseconde.
 * Sans cet en-tête (ancien relais), on redemande toutes les [DEFAULT_INTERVAL_MS].
 * Après des erreurs consécutives : [DEFAULT_INTERVAL_MS] × 1,5ⁿ, plafonné à [MAX_BACKOFF_MS].
 */
object LivePolling {
    const val REFRESH_IN_HEADER = "X-Refresh-In"
    const val DEFAULT_INTERVAL_MS = 15_000L
    const val MIN_INTERVAL_MS = 3_000L
    const val MAX_INTERVAL_MS = 30_000L
    const val MAX_BACKOFF_MS = 60_000L
    const val MAX_SPREAD_MS = 1_000L
    private const val MIN_WAIT_MS = 2_000L

    /** Délai annoncé par le relais, ou null si l'en-tête est absent ou illisible. */
    fun refreshInMs(header: String?): Long? = header?.trim()?.toLongOrNull()?.takeIf { it >= 0 }

    /**
     * Attente avant la requête suivante.
     * @param refreshInMs délai annoncé par la dernière réponse réussie (null : inconnu)
     * @param fetchDurationMs durée de la requête qui vient de se terminer
     * @param consecutiveErrors nombre d'échecs d'affilée (0 si la dernière requête a réussi)
     */
    fun nextDelayMs(refreshInMs: Long?, fetchDurationMs: Long, consecutiveErrors: Int): Long {
        if (consecutiveErrors > 0) {
            val backoff = min((DEFAULT_INTERVAL_MS * 1.5.pow(consecutiveErrors)).toLong(), MAX_BACKOFF_MS)
            return maxOf(backoff - fetchDurationMs, MIN_WAIT_MS)
        }
        if (refreshInMs == null) return maxOf(DEFAULT_INTERVAL_MS - fetchDurationMs, MIN_WAIT_MS)
        return (refreshInMs + Random.nextLong(MAX_SPREAD_MS + 1)).coerceIn(MIN_INTERVAL_MS, MAX_INTERVAL_MS)
    }
}
