package com.alertetcl.android.ui

import androidx.compose.ui.graphics.Color

/**
 * Convertit un code hex `#RRGGBB` ou `#AARRGGBB` (ou sans `#`) en Color Compose.
 */
fun colorFromHex(hex: String): Color {
    val clean = hex.trim().removePrefix("#")
    val full = when (clean.length) {
        6 -> "FF$clean"
        8 -> clean
        else -> "FFFFFFFF"
    }
    return Color(full.toLong(16))
}
