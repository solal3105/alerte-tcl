package com.alertetcl.shared.models

/**
 * Helpers de couleur pour les lignes — retournent des codes hex (ARGB ou RGB)
 * que chaque plateforme convertit en couleur native.
 *
 * Les couleurs proviennent de la charte officielle TCL.
 */
object LineColors {
    /** Couleur de fond pour le pictogramme d'une ligne. Format `#RRGGBB`. */
    fun backgroundHex(line: String): String {
        val u = line.uppercase()
        return when {
            u == "MA" || u == "A" -> "#EE3898"            // Métro A
            u == "MB" || u == "B" -> "#007DC5"            // Métro B
            u == "MC" || u == "C" -> "#F99D1D"            // Métro C
            u == "MD" || u == "D" -> "#00AC4D"            // Métro D
            u == "RX" || u.contains("RHONEXPRESS") -> "#C92B21"
            u.startsWith("TB") -> "#FFCC00"                  // Trolley
            u.startsWith("T") && u.length <= 3 -> "#8C368C"  // Tramways
            u.startsWith("F") && u.length <= 3 -> "#8BC752"  // Funiculaire
            u.startsWith("C") && u.length <= 4 -> "#6E6E73"  // Bus C (gris)
            u.startsWith("JD") -> "#2A2475"                  // Bus JD
            else -> "#FFFFFF"                                // Bus standard
        }
    }

    fun textHex(line: String): String {
        val u = line.uppercase()
        return when {
            u.startsWith("JD") -> "#EBCA2F"
            u.startsWith("C") && u.length <= 4 -> "#FFFFFF"
            u.startsWith("T") && u.length <= 3 -> "#FFFFFF"
            u.startsWith("M") || u in setOf("A", "B", "C", "D") -> "#FFFFFF"
            u.startsWith("F") && u.length <= 3 -> "#FFFFFF"
            u.startsWith("TB") -> "#000000"
            u == "RX" || u.contains("RHONEXPRESS") -> "#FFFFFF"
            u.startsWith("N") -> "#DC7921"
            u.endsWith("E") -> "#5E3A18"
            else -> "#1A1A1A"
        }
    }

    fun needsBorder(line: String): Boolean {
        val u = line.uppercase()
        return !u.startsWith("M") &&
               !u.startsWith("F") &&
               !u.startsWith("C") &&
               !u.startsWith("T") &&
               !u.startsWith("TB") &&
               !u.startsWith("JD") &&
               u !in setOf("A", "B", "C", "D") &&
               !u.contains("RHONEXPRESS") && u != "RX"
    }

    /** Couleur du tracé sur la carte (lignes métro/tram/funiculaire). */
    fun routeStrokeHex(line: String): String {
        val u = line.uppercase()
        return when {
            u == "A" -> "#EE3898"
            u == "B" -> "#007DC5"
            u == "C" -> "#F99D1D"
            u == "D" -> "#00AC4D"
            u == "F1" || u == "F2" -> "#8BC752"
            u in setOf("T1", "T2", "T3", "T4", "T5", "T6", "T7", "TGS") -> "#8C368C"
            u.startsWith("TB") -> "#FFCC00"
            u == "RHONEXPRESS" || u == "RX" -> "#C92B21"
            else -> "#999999"
        }
    }
}
