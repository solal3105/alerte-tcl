package com.alertetcl.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

/**
 * Verre dépoli des surfaces flottantes (tuiles, capsules, boutons de carte) : fond translucide,
 * liseré clair qui accroche la lumière en haut à gauche.
 */
@Composable
fun Modifier.glass(shape: Shape, alpha: Float = 0.62f): Modifier = this
    .clip(shape)
    .background(MaterialTheme.colorScheme.surface.copy(alpha = alpha))
    .border(
        1.dp,
        Brush.linearGradient(listOf(Color.White.copy(alpha = 0.75f), Color.White.copy(alpha = 0.15f))),
        shape
    )
