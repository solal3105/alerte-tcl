package com.alertetcl.shared.network

import kotlinx.coroutines.CancellationException

/**
 * Exécute [block] en préservant l'annulation structurée : les [CancellationException]
 * sont re-lancées telles quelles, toute autre erreur est convertie via [wrap].
 */
suspend inline fun <T> runRethrowingCancellation(wrap: (Throwable) -> ApiError, block: () -> T): T =
    try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        throw wrap(e)
    }

/** Requête réseau : re-lance l'annulation, convertit tout autre échec en [ApiError.NetworkError]. */
suspend inline fun <T> safeRequest(block: () -> T): T =
    runRethrowingCancellation({ ApiError.NetworkError(it) }, block)

/** Décodage de réponse : re-lance l'annulation, convertit tout autre échec en [ApiError.DecodingError]. */
suspend inline fun <T> safeDecode(block: () -> T): T =
    runRethrowingCancellation({ ApiError.DecodingError(it) }, block)
