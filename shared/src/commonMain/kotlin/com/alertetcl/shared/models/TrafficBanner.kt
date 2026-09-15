package com.alertetcl.shared.models

/**
 * Bandeau d'état du trafic affiché sur la carte, calculé une seule fois pour les deux plateformes.
 *
 * Il croise les perturbations en cours (hors simples informations) et les lignes abonnées :
 * sans abonnement, il décrit le réseau ; avec, il décrit d'abord les lignes de l'utilisateur.
 */
object TrafficBanner {
    enum class Tone { NORMAL, WARNING, MAJOR }

    data class State(
        val tone: Tone,
        val title: String,
        val subtitle: String?,
        /** Vrai quand une ligne abonnée est en alerte majeure : l'icône peut battre. */
        val pulsing: Boolean
    )

    /** Une ligne en perturbation et la plus forte sévérité qui la touche. */
    data class LineStatus(val lineId: String, val highestSeverity: AlertSeverity)

    /** Lignes en perturbation (alertes en cours, hors informations), une entrée par ligne. */
    fun linesInError(alerts: List<TCLAlert>, nowEpoch: Long): List<LineStatus> =
        alerts.filter { it.isOngoing(nowEpoch) && it.severity != AlertSeverity.INFO }
            .groupBy { it.ligneCli.ifEmpty { it.ligneCom } }
            .map { (line, lineAlerts) -> LineStatus(line, lineAlerts.minBy { it.severity.sortOrder }.severity) }
            .sortedBy { it.highestSeverity.sortOrder }

    fun compute(subscriptions: Map<String, LineSubscription>, alerts: List<TCLAlert>, nowEpoch: Long): State {
        // À l'échelle du réseau, seules les alertes majeures comptent ; pour les lignes abonnées,
        // toute perturbation en cours (hors information) est prise en compte.
        val networkMajor = alerts.count { it.isOngoing(nowEpoch) && it.severity == AlertSeverity.MAJOR }
        if (subscriptions.isEmpty()) {
            return if (networkMajor == 0) State(Tone.NORMAL, "Réseau TCL normal", "Appuyez pour suivre vos lignes", false)
            else State(Tone.MAJOR, "$networkMajor ${plural(networkMajor, "perturbation")} ${plural(networkMajor, "majeure")} sur le réseau", "Appuyez pour voir les détails", false)
        }
        val mine = linesInError(alerts, nowEpoch).filter { it.lineId in subscriptions }
        if (mine.isEmpty()) {
            return if (networkMajor == 0) State(Tone.NORMAL, "Vos lignes circulent normalement", null, false)
            else State(Tone.NORMAL, "Vos lignes sont normales", "$networkMajor ${plural(networkMajor, "perturbation")} ${plural(networkMajor, "majeure")} sur le réseau", false)
        }
        val major = mine.count { it.highestSeverity == AlertSeverity.MAJOR }
        val others = mine.size - major
        return if (major > 0)
            State(
                Tone.MAJOR,
                "$major ${plural(major, "ligne")} en alerte majeure",
                if (others > 0) "et $others ${plural(others, "autre")} ${plural(others, "ligne")} ${plural(others, "perturbée")}" else null,
                true
            )
        else
            State(Tone.WARNING, "$others de vos ${plural(others, "ligne")} ${plural(others, "perturbée")}", null, false)
    }

    private fun plural(n: Int, word: String): String = if (n > 1) "${word}s" else word
}
