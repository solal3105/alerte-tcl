package com.alertetcl.android.ui.intro

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.Intro
import com.alertetcl.shared.models.IntroIcon
import com.alertetcl.shared.models.IntroPage
import kotlinx.coroutines.launch

/**
 * Écran d'intro : une page par nouveauté, avec les textes du module partagé ([Intro]). Il s'ouvre à la
 * première utilisation et après une mise à jour qui change la révision du contenu, et reste
 * consultable depuis l'onglet Info. Une seule teinte, l'accent.
 */
@Composable
fun IntroScreen(onFinish: () -> Unit) {
    val pages = remember { Intro.pages(includeWidgets = false) }
    val pager = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()
    val isLast = pager.currentPage >= pages.size - 1

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        IntroHalos()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(onClick = onFinish, modifier = Modifier.alpha(if (isLast) 0f else 1f)) {
                    Text(
                        "Passer l'intro",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Tokens.accent
                    )
                }
            }

            HorizontalPager(state = pager, modifier = Modifier.weight(1f)) { position ->
                IntroPageContent(page = pages[position], isCurrent = pager.currentPage == position)
            }

            Row(
                modifier = Modifier.padding(bottom = 28.dp),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                pages.indices.forEach { position ->
                    val current = position == pager.currentPage
                    val width by animateFloatAsState(if (current) 24f else 7f, tween(250), label = "point")
                    Box(
                        modifier = Modifier
                            .width(width.dp)
                            .height(7.dp)
                            .clip(CircleShape)
                            .background(Tokens.accent.copy(alpha = if (current) 1f else 0.22f))
                    )
                }
            }

            Button(
                onClick = {
                    if (isLast) onFinish() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
                },
                colors = ButtonDefaults.buttonColors(containerColor = Tokens.accent),
                shape = RoundedCornerShape(18.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp)
                    .height(54.dp)
            ) {
                Text(
                    Intro.buttonTitle(pager.currentPage, pages.size),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

/** Pictogramme sur disque de verre, titre, texte : les trois arrivent quand la page passe devant. */
@Composable
private fun IntroPageContent(page: IntroPage, isCurrent: Boolean) {
    val appear by animateFloatAsState(
        targetValue = if (isCurrent) 1f else 0f,
        animationSpec = tween(durationMillis = 420),
        label = "apparition"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(116.dp)
                .graphicsLayer {
                    alpha = appear
                    scaleX = 0.86f + 0.14f * appear
                    scaleY = 0.86f + 0.14f * appear
                }
                .glass(CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = page.icon.vector(),
                contentDescription = null,
                tint = Tokens.accent,
                modifier = Modifier.size(52.dp)
            )
        }

        Spacer(Modifier.height(28.dp))

        Text(
            text = page.title,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.graphicsLayer {
                alpha = appear
                translationY = (1f - appear) * 24f
            }
        )

        Spacer(Modifier.height(14.dp))

        Text(
            text = page.body,
            fontSize = 16.sp,
            lineHeight = 23.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.graphicsLayer {
                alpha = appear
                translationY = (1f - appear) * 32f
            }
        )
    }
}

/** Deux halos à l'accent qui dérivent lentement derrière le contenu. */
@Composable
private fun IntroHalos() {
    val transition = rememberInfiniteTransition(label = "halos")
    val drift by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(durationMillis = 14000), RepeatMode.Reverse),
        label = "dérive"
    )
    val accent = Tokens.accent

    Box(modifier = Modifier.fillMaxSize()) {
        Halo(size = 320, alpha = 0.30f, accent = accent, x = -70f + 160f * drift, y = -90f - 80f * drift)
        Halo(size = 260, alpha = 0.22f, accent = accent, x = 120f - 230f * drift, y = 420f + 70f * drift)
    }
}

@Composable
private fun Halo(size: Int, alpha: Float, accent: Color, x: Float, y: Float) {
    Box(
        modifier = Modifier
            .offset(x = x.dp, y = y.dp)
            .size(size.dp)
            .background(
                Brush.radialGradient(listOf(accent.copy(alpha = alpha), Color.Transparent)),
                CircleShape
            )
    )
}

/** Pictogramme de chaque page ; la page d'ouverture porte le tramway de l'icône de l'application. */
private fun IntroIcon.vector(): ImageVector = when (this) {
    IntroIcon.APP -> Icons.Filled.Tram
    IntroIcon.BUS_ARRIVAL -> Icons.Filled.DirectionsBus
    IntroIcon.TIMETABLE -> Icons.Filled.Schedule
    IntroIcon.MAP -> Icons.Filled.Map
    IntroIcon.CITY -> Icons.Filled.NearMe
    IntroIcon.ALERTS -> Icons.Filled.NotificationsActive
    IntroIcon.WIDGETS -> Icons.Filled.Widgets
}

/** L'intro en plein écran, par-dessus l'écran courant. */
@Composable
fun IntroDialog(onFinish: () -> Unit) {
    Dialog(
        onDismissRequest = onFinish,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)
    ) {
        IntroScreen(onFinish = onFinish)
    }
}
