package com.alertetcl.shared.network

import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.UserAgent
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logger
import io.ktor.client.plugins.logging.Logging
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

/** Singleton HTTP client utilisé par tous les services. */
object HttpClientProvider {
    val json: Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
        explicitNulls = false
    }

    val client: HttpClient by lazy {
        HttpClient {
            install(ContentNegotiation) { json(json) }
            install(UserAgent) { agent = NetworkConfiguration.USER_AGENT }
            install(HttpTimeout) {
                requestTimeoutMillis = NetworkConfiguration.HEAVY_TIMEOUT_SECONDS * 1000
                connectTimeoutMillis = NetworkConfiguration.FAST_TIMEOUT_SECONDS * 1000
                socketTimeoutMillis  = NetworkConfiguration.HEAVY_TIMEOUT_SECONDS * 1000
            }
            install(Logging) {
                level = LogLevel.NONE
                logger = object : Logger {
                    override fun log(message: String) { /* noop */ }
                }
            }
            expectSuccess = false
        }
    }
}
