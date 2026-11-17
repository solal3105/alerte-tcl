package com.alertetcl.android.ui.intro

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.alertetcl.android.R
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.Intro
import com.alertetcl.shared.models.IntroPage
import com.alertetcl.shared.models.IntroVisual
import com.alertetcl.shared.models.ParkingType
import kotlinx.coroutines.launch

/**
 * Écran d'intro : une page par nouveauté, illustrée par l'écran correspondant de l'application, avec
 * les textes du module partagé ([Intro]). Il s'ouvre à la première utilisation et après une mise à
 * jour qui change la révision du contenu, et reste consultable depuis l'onglet Info. Les pages
 * dépendent de la révision déjà vue ([seenRevision], [Intro.NEVER_SEEN] depuis l'onglet Info).
 */
@Composable
fun IntroScreen(atLaunch: Boolean, seenRevision: Int, onFinish: () -> Unit) {
    val pages = remember(seenRevision) { Intro.pages(includeWidgets = false, seenRevision = seenRevision) }
    val pager = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()
    val isLast = pager.currentPage >= pages.size - 1
    // Sur les pages de la prévision Vélo'v, les halos prennent la couleur Vélo'v.
    val haloColor by animateColorAsState(
        if (pages[pager.currentPage].visual.isVelovForecast) Tokens.parkingType(ParkingType.VELOV) else Tokens.accent,
        tween(600),
        label = "halos"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        IntroHalos(page = pager.currentPage, color = haloColor)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 2.dp),
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
                // L'illustration glisse moins vite que la page pendant le balayage.
                val parallax = (pager.currentPage - position) + pager.currentPageOffsetFraction
                IntroPageContent(
                    page = pages[position],
                    isCurrent = pager.currentPage == position,
                    parallax = parallax
                )
            }

            Row(
                modifier = Modifier.padding(bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                pages.indices.forEach { position ->
                    val current = position == pager.currentPage
                    val width by animateFloatAsState(if (current) 22f else 6f, tween(250), label = "point")
                    Box(
                        modifier = Modifier
                            .width(width.dp)
                            .height(6.dp)
                            .clip(CircleShape)
                            .background(Tokens.accent.copy(alpha = if (current) 1f else 0.2f))
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
                    .widthIn(max = 460.dp)
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp)
                    .height(54.dp)
            ) {
                Text(
                    Intro.buttonTitle(pager.currentPage, pages.size, atLaunch),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Spacer(Modifier.height(30.dp))
        }
    }
}

/**
 * L'illustration en haut, le titre et le texte en dessous, qui arrivent en cascade après elle. Les pages
 * de la prévision Vélo'v ont un titre et un texte plus grands, sous leur illustration animée.
 */
@Composable
private fun IntroPageContent(page: IntroPage, isCurrent: Boolean, parallax: Float) {
    val visualIn by animateFloatAsState(if (isCurrent) 1f else 0f, tween(durationMillis = 480), label = "illustration")
    val titleIn by appearance(isCurrent, delayMillis = 140, label = "titre")
    val bodyIn by appearance(isCurrent, delayMillis = 260, label = "texte")
    val forecast = page.visual.isVelovForecast

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 30.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .graphicsLayer {
                    translationX = -parallax * size.width * 0.35f
                    alpha = 0.55f + 0.45f * visualIn
                    scaleX = 0.94f + 0.06f * visualIn
                    scaleY = scaleX
                },
            contentAlignment = Alignment.Center
        ) {
            IntroVisualView(page = page, isCurrent = isCurrent)
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.widthIn(max = 380.dp)
        ) {
            Text(
                text = page.title,
                fontSize = if (forecast) 30.sp else 26.sp,
                lineHeight = if (forecast) 35.sp else 31.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.graphicsLayer {
                    alpha = titleIn
                    translationY = (1f - titleIn) * 24f
                }
            )
            Text(
                text = page.body,
                fontSize = if (forecast) 16.sp else 15.sp,
                lineHeight = if (forecast) 23.sp else 22.sp,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.graphicsLayer {
                    alpha = bodyIn
                    translationY = (1f - bodyIn) * 32f
                }
            )
        }
    }
}

/** Arrivée d'un texte de la page, [delayMillis] après l'illustration ; il s'efface sans attendre. */
@Composable
private fun appearance(isCurrent: Boolean, delayMillis: Int, label: String) = animateFloatAsState(
    targetValue = if (isCurrent) 1f else 0f,
    animationSpec = tween(durationMillis = 420, delayMillis = if (isCurrent) delayMillis else 0),
    label = label
)

/**
 * Selon la page : l'icône de l'application, une capture de l'écran concerné, les corrections, ou
 * l'illustration animée d'une page de la prévision Vélo'v.
 */
@Composable
private fun IntroVisualView(page: IntroPage, isCurrent: Boolean) {
    if (page.visual.isVelovForecast) {
        IntroVelovForecastVisual(page.visual, isCurrent)
        return
    }
    when (page.visual) {
        IntroVisual.APP -> Image(
            painter = painterResource(id = R.mipmap.ic_launcher),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(148.dp)
                .clip(RoundedCornerShape(36.dp))
        )
        IntroVisual.FIXES -> Column(
            modifier = Modifier
                .widthIn(max = 340.dp)
                .glass(RoundedCornerShape(26.dp))
                .padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            page.points.forEach { point ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = Tokens.success,
                        modifier = Modifier.size(20.dp)
                    )
                    Text(
                        point,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }
        else -> Image(
            painter = painterResource(id = screenshot(page.visual)),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .widthIn(max = 330.dp)
                .fillMaxSize()
                .clip(RoundedCornerShape(24.dp))
                .border(1.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(24.dp))
        )
    }
}

/** La capture d'écran qui illustre la page. */
private fun screenshot(visual: IntroVisual): Int = when (visual) {
    IntroVisual.STOP -> R.drawable.intro_arret
    IntroVisual.TIMETABLE -> R.drawable.intro_horaires
    IntroVisual.MAP -> R.drawable.intro_carte
    IntroVisual.CITY -> R.drawable.intro_autour
    IntroVisual.VELOV -> R.drawable.intro_velov
    else -> R.drawable.intro_alertes
}

/** Deux halos de [color] (l'accent, ou le Vélo'v) qui dérivent lentement et se replacent à chaque page. */
@Composable
private fun IntroHalos(page: Int, color: Color) {
    val transition = rememberInfiniteTransition(label = "halos")
    val drift by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(durationMillis = 14000), RepeatMode.Reverse),
        label = "dérive"
    )
    val shift by animateFloatAsState(if (page % 2 == 0) -30f else 40f, tween(800), label = "page")

    Box(modifier = Modifier.fillMaxSize()) {
        Halo(size = 360, alpha = 0.32f, color = color, x = -90f + 170f * drift + shift, y = -120f - 70f * drift)
        Halo(size = 300, alpha = 0.20f, color = color, x = 130f - 230f * drift - shift, y = 430f + 60f * drift)
    }
}

@Composable
private fun Halo(size: Int, alpha: Float, color: Color, x: Float, y: Float) {
    Box(
        modifier = Modifier
            .offset(x = x.dp, y = y.dp)
            .size(size.dp)
            .background(
                Brush.radialGradient(listOf(color.copy(alpha = alpha), Color.Transparent)),
                CircleShape
            )
    )
}

/** L'intro en plein écran, par-dessus l'écran courant. */
@Composable
fun IntroDialog(atLaunch: Boolean, seenRevision: Int, onFinish: () -> Unit) {
    Dialog(
        onDismissRequest = onFinish,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)
    ) {
        IntroScreen(atLaunch = atLaunch, seenRevision = seenRevision, onFinish = onFinish)
    }
}
