package com.alertetcl.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.LineColors

/**
 * Pictogramme d'une ligne, le même partout dans l'application : fond et texte de la palette
 * officielle, coins proportionnels à la taille, bordure discrète quand le fond est clair.
 * La taille de police se déduit de la taille et de la longueur du nom si elle n'est pas donnée.
 * Avec une grande taille de texte dans les réglages du téléphone, le badge s'élargit et grandit
 * plutôt que de couper le numéro (« C1 » pour « C13 ») : voir [LineNumberText].
 */
@Composable
fun LineBadge(line: String, size: Dp, fontSize: TextUnit = autoFontSize(line, size)) {
    val shape = RoundedCornerShape(size * 0.2f)
    val outlined = if (LineColors.needsBorder(line))
        Modifier.border(1.dp, MaterialTheme.colorScheme.outlineVariant, shape) else Modifier
    Box(
        modifier = Modifier
            .heightIn(min = size)
            .widthIn(min = size)
            .clip(shape)
            .background(colorFromHex(LineColors.backgroundHex(line)))
            .then(outlined),
        contentAlignment = Alignment.Center
    ) {
        LineNumberText(
            line,
            color = colorFromHex(LineColors.textHex(line)),
            fontSize = fontSize,
            fontWeight = FontWeight.Black,
            modifier = Modifier.padding(horizontal = size * 0.12f, vertical = 2.dp)
        )
    }
}

/**
 * Un numéro de ligne sur une seule ligne, toujours entier. La police suit la taille de texte du
 * téléphone ; si la place offerte ne suffit pas (grille, pictogramme de taille fixe), le texte
 * rapetisse juste assez pour tenir au lieu d'être coupé.
 */
@Composable
fun LineNumberText(
    line: String,
    color: Color,
    fontSize: TextUnit,
    fontWeight: FontWeight,
    modifier: Modifier = Modifier
) {
    BoxWithConstraints(modifier, contentAlignment = Alignment.Center) {
        val measurer = rememberTextMeasurer()
        val maxWidth = constraints.maxWidth
        val bounded = constraints.hasBoundedWidth
        val style = remember(line, color, fontSize, fontWeight, maxWidth, bounded) {
            val base = TextStyle(color = color, fontSize = fontSize, fontWeight = fontWeight)
            val width = measurer.measure(line, base, maxLines = 1, softWrap = false).size.width
            if (!bounded || width <= maxWidth || width == 0) base
            else base.copy(fontSize = fontSize * (maxWidth.toFloat() / width * 0.98f))
        }
        Text(line, style = style, maxLines = 1, softWrap = false)
    }
}

private fun autoFontSize(line: String, size: Dp): TextUnit {
    val ratio = when {
        line.length <= 2 -> 0.42f
        else -> 0.34f
    }
    return (size.value * ratio).sp
}
