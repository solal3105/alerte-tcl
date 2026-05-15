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
    NAVETTE("Navette", "ferry", 5);

    companion object {
        /** Détection à partir du code ligne (M*, T*, F*, C*, JD*, etc.). */
        fun detectFromLine(line: String): TransportMode {
            val u = line.uppercase()
            return when {
                u.startsWith("M") && u.length <= 3 -> METRO
                u.startsWith("T") && u.length <= 3 -> TRAMWAY
                u.startsWith("F") && u.length <= 3 -> FUNICULAR
                u.startsWith("C") && u.length <= 3 -> BUS_C
                u == "RHONEXPRESS" -> TRAMWAY
                else -> BUS
            }
        }

        fun fromString(s: String?): TransportMode = when (s) {
            "Métro" -> METRO
            "Tramway", "Trambus" -> TRAMWAY
            "Bus C" -> BUS_C
            "Funiculaire" -> FUNICULAR
            "Navette maritime/fluviale" -> NAVETTE
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
