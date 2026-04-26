package com.alertetcl.shared.network

/**
 * Configuration réseau partagée. Le proxy Cloudflare détient les credentials
 * Grand Lyon — l'app n'envoie jamais de Authorization.
 */
object NetworkConfiguration {
    const val PROXY_BASE_URL = "https://tcl-proxy.solalgendrin.workers.dev"

    /** Timeout rapide (secondes) — alertes / véhicules. */
    const val FAST_TIMEOUT_SECONDS = 12L

    /** Timeout standard — lignes / parkings. */
    const val SHARED_TIMEOUT_SECONDS = 12L

    /** Timeout long — arrêts (gros volumes). */
    const val HEAVY_TIMEOUT_SECONDS = 18L

    const val USER_AGENT = "AlerteTCL/1.0"
}
