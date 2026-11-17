package com.alertetcl.android.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds

/**
 * Un texte qui défile quand il change, comme un compteur : l'ancien monte et s'efface, le nouveau arrive
 * par le bas, dans sa propre couleur. Sans [rolls], il change sur place (sous le doigt, une animation à
 * chaque cran serait en retard sur le curseur).
 */
@Composable
fun <T> Rolling(
    value: T,
    rolls: Boolean,
    modifier: Modifier = Modifier,
    alignment: Alignment = Alignment.TopStart,
    content: @Composable (T) -> Unit
) {
    if (!rolls) {
        Box(modifier, contentAlignment = alignment) { content(value) }
        return
    }
    AnimatedContent(
        targetState = value,
        modifier = modifier.clipToBounds(),
        transitionSpec = {
            (slideInVertically(tween(ROLL_MS, easing = FastOutSlowInEasing)) { it } + fadeIn(tween(ROLL_MS))) togetherWith
                (slideOutVertically(tween(ROLL_MS, easing = FastOutSlowInEasing)) { -it } + fadeOut(tween(ROLL_MS / 2))) using
                SizeTransform(clip = false)
        },
        contentAlignment = alignment,
        label = "défilement"
    ) { shown -> content(shown) }
}

private const val ROLL_MS = 320
