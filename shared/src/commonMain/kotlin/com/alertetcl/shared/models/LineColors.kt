package com.alertetcl.shared.models

import com.alertetcl.shared.design.AppColors

/**
 * Couleurs des lignes, en codes hex `#RRGGBB` que chaque plateforme convertit en couleur native.
 * Une seule source : la palette officielle du GTFS ([LinePalette], une couleur par ligne, chargée
 * avec l'index des horaires et conservée entre deux lancements). Tant qu'une ligne n'y figure pas,
 * elle est neutre (fond discret avec liseré, texte foncé) : aucune charte n'est écrite en dur.
 */
object LineColors {
    /** Couleur de fond pour le pictogramme d'une ligne. */
    fun backgroundHex(line: String): String =
        LinePalette.colorFor(line)?.backgroundHex ?: AppColors.neutralFill.light

    fun textHex(line: String): String =
        LinePalette.colorFor(line)?.textHex ?: AppColors.onLight

    /** Vrai si le fond est clair au point de se confondre avec un fond blanc (ou inconnu). */
    fun needsBorder(line: String): Boolean =
        LinePalette.colorFor(line)?.let { isLight(it.backgroundHex) } ?: true

    /** Couleur du tracé sur la carte. */
    fun routeStrokeHex(line: String): String =
        LinePalette.colorFor(line)?.backgroundHex ?: AppColors.routeUnknown

    /** Luminance relative d'une couleur `#RRGGBB` ; au-delà de 0,85 elle est considérée claire. */
    private fun isLight(hex: String): Boolean {
        val c = hex.removePrefix("#")
        if (c.length != 6) return false
        val r = c.substring(0, 2).toInt(16)
        val g = c.substring(2, 4).toInt(16)
        val b = c.substring(4, 6).toInt(16)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0 > 0.85
    }
}
