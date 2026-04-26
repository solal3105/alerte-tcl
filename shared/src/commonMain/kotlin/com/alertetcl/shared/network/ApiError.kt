package com.alertetcl.shared.network

/** Erreurs unifiées pour tous les services réseau. */
sealed class ApiError(message: String, cause: Throwable? = null) : Exception(message, cause) {
    object InvalidUrl       : ApiError("URL invalide")
    object InvalidResponse  : ApiError("Réponse invalide du serveur")
    object Unauthorized     : ApiError("Authentification requise")
    object Forbidden        : ApiError("Accès refusé")
    object NotFound         : ApiError("Service non trouvé")
    data class ServerError(val code: Int) : ApiError("Erreur serveur ($code)")
    data class HttpError(val code: Int)   : ApiError("Erreur HTTP ($code)")
    data class DecodingError(val cause0: Throwable) : ApiError("Erreur de décodage", cause0)
    data class NetworkError(val cause0: Throwable)  : ApiError("Erreur réseau", cause0)
}
