package com.alertetcl.shared.models

import kotlinx.serialization.Serializable

@Serializable
enum class AlertSeverity(val displayName: String, val sortOrder: Int) {
    MAJOR("Perturbation majeure", 0),
    DISRUPTION("Perturbation", 1),
    INFO("Information", 2);

    val colorKey: String get() = when (this) {
        MAJOR      -> "alertDanger"
        DISRUPTION -> "alertWarning"
        INFO       -> "alertInfo"
    }
}

/**
 * Alerte trafic TCL.
 * Equivalent du Swift `TCLAlert` — les dates sont en epoch seconds (UTC) pour
 * être consommables par toutes les plateformes.
 */
@Serializable
data class TCLAlert(
    val id: String,
    val type: String,
    val cause: String,
    val debutEpoch: Long? = null,
    val finEpoch: Long? = null,
    val mode: TransportMode,
    val ligneCom: String,
    val ligneCli: String,
    val titre: String,
    val message: String,
    val niveauSeverite: Int? = null
) {
    val severity: AlertSeverity get() {
        val t = type.lowercase()
        return when {
            "majeure" in t -> AlertSeverity.MAJOR
            "perturbation" in t -> AlertSeverity.DISRUPTION
            else -> AlertSeverity.INFO
        }
    }

    fun isActive(nowEpoch: Long): Boolean {
        val end = finEpoch ?: return true
        return nowEpoch <= end
    }

    fun hasStarted(nowEpoch: Long): Boolean {
        val start = debutEpoch ?: return true
        return start <= nowEpoch
    }

    fun isOngoing(nowEpoch: Long): Boolean = isActive(nowEpoch) && hasStarted(nowEpoch)
    fun isUpcoming(nowEpoch: Long): Boolean = isActive(nowEpoch) && !hasStarted(nowEpoch)

    fun notificationKey(phase: AlertNotificationPhase): String {
        val contentHash = (titre + message).hashCode()
        return "$id|${phase.name}|$contentHash"
    }
}

enum class AlertNotificationPhase { ANNOUNCED, ACTIVE }
