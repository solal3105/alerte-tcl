package com.alertetcl.shared.models

/**
 * Règle commune de notification des alertes trafic, identique sur iOS et Android.
 *
 * Une alerte est notifiée au plus deux fois : quand elle est annoncée (à venir) et quand elle
 * commence (en cours). Les clés déjà vues évitent les doublons ; au premier lancement, tout ce
 * qui existe déjà est marqué vu sans notification pour ne pas inonder l'utilisateur.
 */
object AlertNotifications {
    data class Pending(val alert: TCLAlert, val phase: AlertNotificationPhase) {
        val key: String get() = alert.notificationKey(phase)
    }

    /** Nombre maximal de clés conservées ; au-delà, on garde la moitié la plus récente. */
    const val MAX_SEEN_KEYS = 500

    /** Clés à marquer vues silencieusement au premier lancement. */
    fun baselineKeys(alerts: List<TCLAlert>, subscriptions: Map<String, LineSubscription>): Set<String> =
        alerts.filter { subscribedLine(subscriptions, it) }
            .flatMap { alert -> AlertNotificationPhase.entries.map { alert.notificationKey(it) } }
            .toSet()

    /** Notifications à émettre maintenant, dans l'ordre du flux. */
    fun pending(
        alerts: List<TCLAlert>,
        subscriptions: Map<String, LineSubscription>,
        seenKeys: Set<String>,
        nowEpoch: Long
    ): List<Pending> = alerts
        .filter { it.isActive(nowEpoch) && LineSubscriptions.concerns(subscriptions, it) }
        .flatMap { alert ->
            buildList {
                if (alert.isUpcoming(nowEpoch)) add(Pending(alert, AlertNotificationPhase.ANNOUNCED))
                if (alert.isOngoing(nowEpoch)) add(Pending(alert, AlertNotificationPhase.ACTIVE))
            }
        }
        .filter { it.key !in seenKeys }

    /** Clés vues après ajout, purgées si elles dépassent [MAX_SEEN_KEYS]. */
    fun remember(seenKeys: List<String>, newKeys: Collection<String>): List<String> {
        val merged = seenKeys.toMutableList()
        newKeys.forEach { if (it !in merged) merged += it }
        return if (merged.size > MAX_SEEN_KEYS) merged.takeLast(MAX_SEEN_KEYS / 2) else merged
    }

    fun title(alert: TCLAlert, phase: AlertNotificationPhase): String {
        val line = alert.ligneCli.ifEmpty { alert.ligneCom }
        val label = "${alert.mode.displayName} $line"
        return when (phase) {
            AlertNotificationPhase.ANNOUNCED -> "$label : à venir"
            AlertNotificationPhase.ACTIVE -> label
        }
    }

    fun subtitle(alert: TCLAlert, phase: AlertNotificationPhase): String = when (phase) {
        AlertNotificationPhase.ANNOUNCED -> "À venir : ${alert.titre}"
        AlertNotificationPhase.ACTIVE -> alert.titre
    }

    /** Vrai si la ligne de l'alerte est abonnée, quel que soit le type d'alerte. */
    private fun subscribedLine(subscriptions: Map<String, LineSubscription>, alert: TCLAlert): Boolean =
        alert.ligneCom in subscriptions || (alert.ligneCli.isNotEmpty() && alert.ligneCli in subscriptions)
}
