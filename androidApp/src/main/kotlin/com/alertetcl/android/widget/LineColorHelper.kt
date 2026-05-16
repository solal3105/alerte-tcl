package com.alertetcl.android.widget

import androidx.compose.ui.graphics.Color

internal object LineColorHelper {

    fun backgroundColor(ligne: String): Color {
        val u = ligne.uppercase().trim()
        return when {
            u == "MA" || u == "A"                        -> Color(0xFFEE3898)
            u == "MB" || u == "B"                        -> Color(0xFF007DC5)
            u == "MC" || u == "C"                        -> Color(0xFFF99D1D)
            u == "MD" || u == "D"                        -> Color(0xFF00AC4D)
            u == "RX" || u.contains("RHONEXPRESS")       -> Color(0xFFC92B21)
            u.startsWith("TB")                           -> Color(0xFFFFCC00)
            u.startsWith("T") && u.length <= 3           -> Color(0xFF673878)
            u.startsWith("JD")                           -> Color(0xFF2A2475)
            u.startsWith("F") && u.length <= 3           -> Color(0xFFFF6600)
            u.startsWith("C") && u.length <= 4           -> Color(0xFF888888)
            else                                         -> Color(0xFF1565C0)
        }
    }

    fun textColor(ligne: String): Color {
        val u = ligne.uppercase().trim()
        return when {
            u == "MC" || u == "C" -> Color(0xFF1A1A1A)
            u.startsWith("TB")    -> Color(0xFF1A1A1A)
            else                  -> Color.White
        }
    }

    /** One-character transport type label used as a text icon in Glance rows. */
    fun vehicleLabel(ligne: String): String {
        val u = ligne.uppercase().trim()
        return when {
            u.startsWith("M") || u in setOf("A", "B", "C", "D") -> "M"
            u.startsWith("T")                                     -> "T"
            else                                                  -> "→"
        }
    }
}
