package com.alertetcl.shared.models

import kotlinx.serialization.Serializable

@Serializable
enum class AlertSeverity(val displayName: String, val sortOrder: Int) {
    MAJOR("Perturbation majeure", 0),
    DISRUPTION("Perturbation", 1),
    INFO("Information", 2);

    /** Ce que la notification et la feuille d'options disent de ce type d'alerte. */
    val description: String get() = when (this) {
        MAJOR      -> "Interruptions totales de service"
        DISRUPTION -> "Retards et déviations importantes"
        INFO       -> "Informations et travaux prévus"
    }

    companion object {
        fun fromDisplayName(name: String): AlertSeverity? = entries.firstOrNull { it.displayName == name }
    }
}

/**
 * Identité d'une alerte, tirée de son contenu.
 *
 * Le flux TCL numérote ses alertes par leur rang dans la réponse (1, 2, 3…) : ce numéro change dès
 * qu'une alerte apparaît ou disparaît de la liste, si bien qu'il ne reconnaît pas une perturbation
 * d'un jour à l'autre. Tant qu'il servait d'identifiant, les mêmes notifications repartaient tous
 * les jours. L'identité vient donc de la ligne, du titre, du début et d'une empreinte du message,
 * qui distingue les alertes que TCL publie en double sur une même ligne.
 */
object AlertIdentity {
    fun of(ligneCom: String, ligneCli: String, titre: String, debut: String?, message: String): String {
        val heart = "${ligneCom.trim()}|${ligneCli.trim()}|${titre.trim()}|${debut?.trim().orEmpty()}"
        return "$heart|${fingerprint(message.trim())}"
    }

    /** Empreinte FNV-1a sur 32 bits : courte, stable, la même sur les deux plateformes. */
    private fun fingerprint(text: String): String {
        var hash = 2166136261u
        for (char in text) {
            hash = hash xor char.code.toUInt()
            hash *= 16777619u
        }
        return hash.toString(16)
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

    fun notificationKey(phase: AlertNotificationPhase): String = "$id|${phase.name}"
}

enum class AlertNotificationPhase { ANNOUNCED, ACTIVE }
