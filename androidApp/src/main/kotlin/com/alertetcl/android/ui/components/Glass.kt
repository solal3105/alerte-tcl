package com.alertetcl.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
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

/** Taches de couleur floues derrière les surfaces en verre. */
@Composable
fun GlassBackdrop(colors: List<Color>, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        val placements = listOf(
            Triple((-80).dp, (-40).dp, 420.dp),
            Triple(160.dp, 120.dp, 380.dp),
            Triple((-60).dp, 420.dp, 360.dp),
            Triple(140.dp, 620.dp, 400.dp),
            Triple(20.dp, 260.dp, 300.dp),
        )
        colors.forEachIndexed { i, color ->
            val (x, y, size) = placements[i % placements.size]
            Blob(color, x, y, size)
        }
    }
}

@Composable
private fun Blob(color: Color, x: Dp, y: Dp, size: Dp) {
    Box(
        modifier = Modifier
            .offset(x, y)
            .size(size)
            .background(Brush.radialGradient(listOf(color.copy(alpha = 0.55f), color.copy(alpha = 0f))), CircleShape)
    )
}
