package com.alertetcl.shared.models

import kotlinx.serialization.Serializable

/**
 * Quand une prévision Vélo'v peut être montrée, et quand redemander au relais où en est le modèle.
 * Toutes les heures sont en secondes epoch.
 */
object VelovForecastFreshness {
    /**
     * Un modèle que le robot hebdomadaire n'a pas confirmé depuis ce nombre de jours ne sert plus :
     * l'application n'affiche alors aucune prévision, plutôt qu'une prévision que plus rien ne garantit.
     */
    const val MAX_VERIFIED_AGE_DAYS = 21

    /** Le relais n'est interrogé qu'une fois par jour… */
    const val CHECK_INTERVAL_SECONDS = 86_400L

    /** …et, tant qu'il ne répond pas, pas plus d'une fois par quart d'heure. */
    const val RETRY_INTERVAL_SECONDS = 900L

    fun canShow(verifiedAt: Long, now: Long): Boolean = now - verifiedAt < MAX_VERIFIED_AGE_DAYS * 86_400L

    /**
     * @param checkedAt dernière réponse du relais
     * @param attemptedAt dernière demande, aboutie ou non, depuis le lancement (0 : aucune)
     */
    fun isCheckDue(checkedAt: Long, attemptedAt: Long, now: Long): Boolean =
        elapsed(checkedAt, now, CHECK_INTERVAL_SECONDS) && elapsed(attemptedAt, now, RETRY_INTERVAL_SECONDS)

    /** Une heure enregistrée dans le futur (horloge reculée) compte comme échue. */
    private fun elapsed(since: Long, now: Long, interval: Long): Boolean = now - since !in 0 until interval
}

/**
 * Ce que l'appareil retient du modèle qu'il garde sur disque : sa version, son dernier contrôle
 * par le robot et la dernière réponse du relais.
 */
@Serializable
internal data class VelovForecastReceipt(
    val version: String = "",
    val verifiedAt: Long = 0,
    val checkedAt: Long = 0
) {
    fun canShow(now: Long): Boolean = VelovForecastFreshness.canShow(verifiedAt, now)

    /**
     * Le reçu ne vaut que pour le modèle réellement relu du disque ([heldVersion], null s'il n'y en a
     * pas) : sinon on repart d'un reçu jamais contrôlé, donc ni affichable ni dispensé de demande.
     */
    fun matching(heldVersion: String?): VelovForecastReceipt =
        if (heldVersion == version) this else VelovForecastReceipt(version = heldVersion.orEmpty())

    /** Vrai si le relais annonce, dans un format que l'application sait lire, un autre modèle que celui gardé. */
    fun isOutdatedBy(index: VelovForecastIndex): Boolean =
        index.format == VelovForecastBundle.FORMAT && index.version != version

    /**
     * Reçu après une réponse du relais qui n'appelle pas de téléchargement : le contrôle annoncé ne
     * compte que s'il porte sur la version gardée (un format inconnu laisse donc le modèle vieillir).
     */
    fun answeredBy(index: VelovForecastIndex, now: Long): VelovForecastReceipt {
        val confirmed = index.format == VelovForecastBundle.FORMAT && index.version == version
        return copy(verifiedAt = if (confirmed) index.verifiedAt else verifiedAt, checkedAt = now)
    }
}
