package com.alertetcl.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.LineColors

/**
 * Pictogramme d'une ligne, le même partout dans l'application : fond et texte de la palette
 * officielle, coins proportionnels à la taille, bordure discrète quand le fond est clair.
 * La taille de police se déduit de la taille et de la longueur du nom si elle n'est pas donnée ;
 * un nom long (C20E, JD205) élargit le badge plutôt que d'être coupé.
 */
@Composable
fun LineBadge(line: String, size: Dp, fontSize: TextUnit = autoFontSize(line, size)) {
    val shape = RoundedCornerShape(size * 0.2f)
    val outlined = if (LineColors.needsBorder(line))
        Modifier.border(1.dp, MaterialTheme.colorScheme.outlineVariant, shape) else Modifier
    Box(
        modifier = Modifier
            .height(size)
            .widthIn(min = size)
            .clip(shape)
            .background(colorFromHex(LineColors.backgroundHex(line)))
            .then(outlined),
        contentAlignment = Alignment.Center
    ) {
        Text(
            line,
            modifier = Modifier.padding(horizontal = size * 0.12f),
            color = colorFromHex(LineColors.textHex(line)),
            fontSize = fontSize,
            fontWeight = FontWeight.Black,
            maxLines = 1,
            softWrap = false
        )
    }
}

private fun autoFontSize(line: String, size: Dp): TextUnit {
    val ratio = when {
        line.length <= 2 -> 0.42f
        else -> 0.34f
    }
    return (size.value * ratio).sp
}
