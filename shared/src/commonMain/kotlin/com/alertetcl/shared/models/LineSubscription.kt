package com.alertetcl.shared.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Abonnement aux notifications d'une ligne : la ligne et les types d'alertes souhaités.
 *
 * Les types sont stockés par leur libellé ([AlertSeverity.displayName]) pour rester lisibles et
 * compatibles avec les abonnements déjà enregistrés sur iOS (clé `lineSubscriptions`).
 */
@Serializable
data class LineSubscription(
    val lineId: String,
    val notificationTypes: Set<String>
) {
    val severities: Set<AlertSeverity>
        get() = notificationTypes.mapNotNull { AlertSeverity.fromDisplayName(it) }.toSet()
}

/**
 * Règles et encodage des abonnements, partagés par les deux plateformes.
 *
 * Un abonnement est indépendant des lignes favorites (qui ne servent qu'aux filtres de la carte).
 * Une ligne est enregistrée sous son code commercial et, s'il diffère, sous son code client,
 * car le flux d'alertes peut désigner l'une ou l'autre forme.
 */
object LineSubscriptions {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    val allSeverities: Set<AlertSeverity> get() = AlertSeverity.entries.toSet()

    fun decode(encoded: String?): Map<String, LineSubscription> {
        if (encoded.isNullOrBlank()) return emptyMap()
        return runCatching { json.decodeFromString<Map<String, LineSubscription>>(encoded) }
            .getOrDefault(emptyMap())
    }

    fun encode(subscriptions: Map<String, LineSubscription>): String = json.encodeToString(subscriptions)

    fun isSubscribed(subscriptions: Map<String, LineSubscription>, line: TransportLine): Boolean =
        line.ligneCom in subscriptions || (line.ligneCli.isNotEmpty() && line.ligneCli in subscriptions)

    /** Types d'alertes choisis pour la ligne ; tous par défaut. */
    fun preferences(subscriptions: Map<String, LineSubscription>, line: TransportLine): Set<AlertSeverity> {
        val sub = subscriptions[line.ligneCom] ?: subscriptions[line.ligneCli] ?: return allSeverities
        return sub.severities
    }

    fun subscribe(
        subscriptions: Map<String, LineSubscription>,
        line: TransportLine,
        severities: Set<AlertSeverity> = allSeverities
    ): Map<String, LineSubscription> {
        if (severities.isEmpty()) return unsubscribe(subscriptions, line)
        val types = severities.map { it.displayName }.toSet()
        val result = subscriptions.toMutableMap()
        keysFor(line).forEach { result[it] = LineSubscription(it, types) }
        return result
    }

    fun unsubscribe(subscriptions: Map<String, LineSubscription>, line: TransportLine): Map<String, LineSubscription> {
        val result = subscriptions.toMutableMap()
        keysFor(line).forEach { result.remove(it) }
        return result
    }

    fun toggle(subscriptions: Map<String, LineSubscription>, line: TransportLine): Map<String, LineSubscription> =
        if (isSubscribed(subscriptions, line)) unsubscribe(subscriptions, line) else subscribe(subscriptions, line)

    /** Lignes abonnées parmi [lines], sans doublon entre code commercial et code client. */
    fun subscribedLines(subscriptions: Map<String, LineSubscription>, lines: List<TransportLine>): List<TransportLine> =
        lines.filter { isSubscribed(subscriptions, it) }

    /** Vrai si l'alerte concerne une ligne abonnée et un type d'alerte retenu pour cette ligne. */
    fun concerns(subscriptions: Map<String, LineSubscription>, alert: TCLAlert): Boolean {
        val sub = subscriptions[alert.ligneCom]
            ?: alert.ligneCli.takeIf { it.isNotEmpty() }?.let { subscriptions[it] }
            ?: return false
        return alert.severity in sub.severities
    }

    /**
     * Reprise des anciennes préférences Android (lignes favorites + sévérités par ligne) vers des
     * abonnements ; ne fait rien si des abonnements existent déjà.
     */
    fun migrateFromFavorites(
        existing: Map<String, LineSubscription>,
        favoriteLines: Set<String>,
        severityPreferences: Map<String, Set<AlertSeverity>>,
        lines: List<TransportLine>
    ): Map<String, LineSubscription> {
        if (existing.isNotEmpty() || favoriteLines.isEmpty()) return existing
        var result = existing
        favoriteLines.forEach { id ->
            val line = lines.firstOrNull { it.ligneCom == id || it.ligneCli == id }
                ?: TransportLine.create(id, "", TransportMode.detectFromLine(id))
            result = subscribe(result, line, severityPreferences[id] ?: allSeverities)
        }
        return result
    }

    private fun keysFor(line: TransportLine): List<String> =
        if (line.ligneCli.isNotEmpty() && line.ligneCli != line.ligneCom) listOf(line.ligneCom, line.ligneCli)
        else listOf(line.ligneCom)
}
