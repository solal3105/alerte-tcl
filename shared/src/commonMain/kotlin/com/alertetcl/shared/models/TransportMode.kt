package com.alertetcl.shared.models

import kotlinx.serialization.Serializable

/**
 * Mode de transport. Les noms d'icônes sont des identifiants neutres (l'UI native
 * les mappe vers SF Symbols sur iOS ou des Material Icons sur Android).
 */
@Serializable
enum class TransportMode(val displayName: String, val iconKey: String, val sortOrder: Int) {
    METRO("Métro", "metro", 0),
    FUNICULAR("Funiculaire", "funicular", 1),
    TRAMWAY("Tramway", "tram", 2),
    BUS_C("Bus C", "bus_c", 3),
    BUS("Bus", "bus", 4),
    NAVIGONE("Navigone", "ferry", 5);

    /**
     * Vrai si le flux temps réel de positions (SIRI) suit les véhicules de ce mode. Le métro et
     * les funiculaires n'y figurent jamais : proposer de les « voir sur la carte » n'aurait aucun sens.
     */
    val hasLiveVehicles: Boolean get() = this != METRO && this != FUNICULAR

    /** Libellé du bouton qui filtre la carte sur les véhicules d'une ligne, ou null si le mode n'est pas suivi. */
    val showOnMapLabel: String? get() = when (this) {
        METRO, FUNICULAR -> null
        TRAMWAY -> "Voir ces trams sur la carte"
        NAVIGONE -> "Voir cette navette sur la carte"
        BUS_C, BUS -> "Voir ces bus sur la carte"
    }

    companion object {
        /** Détection à partir du code ligne (M*, T*, F*, C*, JD*, etc.). */
        fun detectFromLine(line: String): TransportMode {
            val u = line.uppercase()
            // D'abord les lignes du réseau telles que publiées dans l'index des horaires (à jour chaque nuit).
            LineRegistry.modeOf(u)?.let { return it }
            // Heuristique sur le nom pour une ligne que l'index ne connaît pas encore (alignée sur iOS).
            return when {
                u.startsWith("M") && u.length <= 3 -> METRO
                u in setOf("A", "B", "C", "D") -> METRO
                u.startsWith("TB") -> TRAMWAY
                u.length == 2 && u[0] == 'T' && u[1].isDigit() -> TRAMWAY
                u.startsWith("F") && u.length <= 3 -> FUNICULAR
                u.length >= 2 && u[0] == 'C' && u[1].isDigit() -> BUS_C
                u == "RHONEXPRESS" -> TRAMWAY
                u.startsWith("NAVI") || u == "7601" || u == "N1" -> NAVIGONE
                else -> BUS
            }
        }

        /** Classifie la hiérarchie d'affichage d'un arrêt selon les lignes qui le desservent. */
        fun classifyStopTier(lines: List<String>): TransportMode {
            val modes = lines.map { detectFromLine(it) }
            return when {
                METRO   in modes -> METRO
                TRAMWAY in modes -> TRAMWAY
                BUS_C   in modes -> BUS_C
                else             -> BUS
            }
        }

        /** Première ligne de la hiérarchie la plus haute parmi [lines]. */
        fun primaryStopLine(lines: List<String>): String? =
            lines.minByOrNull { detectFromLine(it).sortOrder }

        fun fromString(s: String?): TransportMode = when (s) {
            "Métro" -> METRO
            "Tramway", "Trambus" -> TRAMWAY
            "Bus C" -> BUS_C
            "Funiculaire" -> FUNICULAR
            "Navette maritime/fluviale", "Navette" -> NAVIGONE
            else -> BUS
        }
    }
}

@Serializable
data class TransportLine(
    val id: String,
    val ligneCom: String,
    val ligneCli: String,
    val mode: TransportMode
) {
    val displayName: String get() = if (ligneCli.isNotEmpty()) ligneCli else ligneCom

    companion object {
        fun create(ligneCom: String, ligneCli: String, mode: TransportMode): TransportLine =
            TransportLine(id = "${mode.displayName}-$ligneCom", ligneCom = ligneCom, ligneCli = ligneCli, mode = mode)
    }
}
