package com.alertetcl.android.ui.intro

import android.provider.Settings
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.components.Rolling
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.parking.ChartFrame
import com.alertetcl.android.ui.parking.VelovCard
import com.alertetcl.android.ui.parking.VelovForecastChart
import com.alertetcl.android.ui.parking.VelovReadout
import com.alertetcl.android.ui.parking.VelovRiskRow
import com.alertetcl.android.ui.parking.VelovTickRow
import com.alertetcl.android.ui.parking.VelovTimePanel
import com.alertetcl.android.ui.parking.VelovTimeTrack
import com.alertetcl.android.ui.parking.pointAt
import com.alertetcl.android.ui.parking.velovMarkerBitmap
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.design.AppColors
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.IntroVisual
import com.alertetcl.shared.models.VelovChance
import com.alertetcl.shared.models.VelovChanceLevel
import com.alertetcl.shared.models.VelovForecast
import com.alertetcl.shared.models.VelovForecastDemo
import com.alertetcl.shared.models.VelovForecastMapPanel
import com.alertetcl.shared.models.VelovForecastMarker
import com.alertetcl.shared.models.VelovForecastPanel
import com.alertetcl.shared.models.VelovForecastReadout
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.min
import kotlin.math.roundToInt

// Les trois illustrations animées de la prévision Vélo'v dans l'intro (révision 2 ; règles dans DESIGN.md,
// « Pages de la prévision Vélo'v »). Elles ne dessinent qu'avec les briques de la fiche et de la carte
// (VelovForecastViews.kt, VelovViews.kt), nourries par la démonstration du module partagé
// (`VelovForecastDemo`) : aucun texte ni aucun chiffre n'est écrit ici. Ce fichier ne fait que la mise en
// scène : où poser les briques, et quand les faire bouger.
//
// Chaque scène est dessinée à une taille fixe puis réduite d'un bloc si la place manque (petits
// téléphones) : rien n'y est coupé, et la taille du texte du téléphone ne la déforme pas (l'illustration
// est muette pour les lecteurs d'écran ; le titre et le texte de la page, eux, suivent le réglage).

/** Vrai pour les trois pages de la prévision Vélo'v : illustrées ici, avec des halos à la couleur Vélo'v. */
internal val IntroVisual.isVelovForecast: Boolean
    get() = when (this) {
        IntroVisual.VELOV_FORECAST_MAP,
        IntroVisual.VELOV_FORECAST_RANGE,
        IntroVisual.VELOV_FORECAST_CHANCE -> true
        else -> false
    }

/**
 * L'illustration d'une page de la prévision Vélo'v, posée sur sa carte de verre. Elle repart de zéro
 * quand sa page passe devant ([isCurrent]) et tourne en boucle tant qu'elle y reste ; hors de la page,
 * elle attend au départ. Avec « Réduire les animations », elle montre son image la plus parlante.
 */
@Composable
internal fun IntroVelovForecastVisual(visual: IntroVisual, isCurrent: Boolean) {
    val playback = Playback(isCurrent, rememberReducedMotion())
    IntroStage {
        when (visual) {
            IntroVisual.VELOV_FORECAST_MAP -> MapScene(playback)
            IntroVisual.VELOV_FORECAST_RANGE -> RangeScene(playback)
            IntroVisual.VELOV_FORECAST_CHANCE -> ChanceScene(playback)
            else -> Unit
        }
    }
}

// --- Mise en scène commune ---

private val StageWidth = 320.dp
private val StageHeight = 440.dp
private val StageShape = RoundedCornerShape(30.dp)

/** Demi-hauteur d'un marqueur de station (`velovMarkerBitmap`) : c'est son centre qui tombe sur la station. */
private val MarkerHalfHeight = 15.dp

/** Les arrêts du curseur de la démonstration ([VelovForecastDemo.TOUR]) et ceux que les scènes nomment. */
private val TOUR = VelovForecastDemo.TOUR
private val MORNING = TOUR[1] // 8 h 30 : la station se vide.
private val EMPTY = TOUR[2] // 9 h 15 : vide.
private val NOON = TOUR[3]
private val EVENING = TOUR[4] // 19 h 30 : les bureaux se vident, les trois couleurs à la fois sur la carte.

/** La fourchette parcourue au fil de la journée, de 8 h 30 à 19 h 30 : elle s'élargit avec l'heure. */
private val RANGE_TOUR = TOUR.subList(1, TOUR.lastIndex)

/** Ce qui décide si une illustration bouge : sa page est-elle devant, le téléphone réduit-il les animations. */
@Immutable
private data class Playback(val isCurrent: Boolean, val reduced: Boolean)

/** « Réduire les animations » (ou les animations coupées dans les options pour les développeurs). */
@Composable
private fun rememberReducedMotion(): Boolean {
    val resolver = LocalContext.current.contentResolver
    return remember(resolver) { Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }
}

/**
 * Fait vivre une scène : sa page devant, [loop] tourne sans fin, chaque tour repartant de [rewind] ; hors
 * de la page, [rewind] la remet au départ ; avec les animations réduites, [still] la pose sur son image
 * fixe.
 */
@Composable
private fun Play(playback: Playback, rewind: suspend () -> Unit, still: suspend () -> Unit, loop: suspend () -> Unit) {
    LaunchedEffect(playback) {
        if (playback.reduced) {
            still()
            return@LaunchedEffect
        }
        rewind()
        if (!playback.isCurrent) return@LaunchedEffect
        while (true) {
            loop()
            rewind()
        }
    }
}

/**
 * La scène : une carte de verre arrondie, à ombre douce, dessinée à sa taille fixe et réduite d'un bloc
 * si la place manque. Muette pour les lecteurs d'écran.
 */
@Composable
private fun IntroStage(content: @Composable BoxScope.() -> Unit) {
    val density = LocalDensity.current
    Box(modifier = Modifier.fillMaxSize().clearAndSetSemantics { }, contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .fitted(StageWidth, StageHeight)
                .shadow(14.dp, StageShape)
                .glass(StageShape, alpha = 0.86f)
        ) {
            CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale = 1f)) {
                Box(modifier = Modifier.fillMaxSize(), content = content)
            }
        }
    }
}

/** Mesure le contenu à [width] × [height] et le réduit d'un bloc, sans le recomposer, s'il ne tient pas. */
private fun Modifier.fitted(width: Dp, height: Dp): Modifier = layout { measurable, constraints ->
    val w = width.roundToPx()
    val h = height.roundToPx()
    val scale = minOf(1f, constraints.maxWidth.toFloat() / w, constraints.maxHeight.toFloat() / h)
    val placeable = measurable.measure(Constraints.fixed(w, h))
    layout((w * scale).roundToInt(), (h * scale).roundToInt()) {
        placeable.placeWithLayer(0, 0) {
            scaleX = scale
            scaleY = scale
            transformOrigin = TransformOrigin(0f, 0f)
        }
    }
}

/** Le doigt se pose sur le pouce, le fait glisser jusqu'à [to], se lève, et la scène s'arrête [hold] ms. */
private suspend fun slideThumb(
    thumb: Animatable<Float, AnimationVector1D>,
    finger: Animatable<Float, AnimationVector1D>,
    to: Int,
    hold: Long
) = coroutineScope {
    finger.animateTo(1f, tween(160))
    thumb.animateTo(to.toFloat(), tween(700, easing = FastOutSlowInEasing))
    launch { finger.animateTo(0f, tween(260)) }
    delay(hold)
}

// --- La démonstration, lue une fois ---

/**
 * Ce que les scènes lisent de [VelovForecastDemo], calculé une fois pour toutes : les textes de la fiche
 * et les marqueurs de la carte aux 97 échéances, les panneaux du curseur de la carte.
 */
private object DemoFrames {
    private val steps = 0..VelovForecast.STEP_COUNT
    val panel: VelovForecastPanel by lazy { VelovForecastDemo.sheet.panel(VelovForecastDemo.SHEET_FILTER) }
    val readouts: List<VelovForecastReadout> by lazy { steps.map { VelovForecastDemo.sheet.readout(VelovForecastDemo.SHEET_FILTER, it) } }
    val markers: List<List<VelovForecastMarker>> by lazy { steps.map { VelovForecastDemo.markers(it) } }
    val mapPanels: List<VelovForecastMapPanel> by lazy { steps.map { VelovForecastMapPanel.at(VelovForecastDemo.ORIGIN_EPOCH_MS, it) } }

    /** La place des stations sur le plan, dans l'ordre de [VelovForecastDemo.pins]. */
    val points: List<Offset> by lazy { VelovForecastDemo.pins.map { Offset(it.x.toFloat(), it.y.toFloat()) } }

    /** Les marqueurs différents de la carte sur toute la journée. */
    val mapLooks: List<MarkerLook> by lazy { markers.flatten().map { it.look }.distinct() }
}

// --- Marqueurs ---

/** Ce qui distingue l'image d'un marqueur : son libellé et sa couleur. */
private data class MarkerLook(val label: String, val availability: AvailabilityColor)

private val VelovForecastMarker.look: MarkerLook get() = MarkerLook(label, availability)

/**
 * Les images des marqueurs [looks], celles de la vraie carte (`velovMarkerBitmap`), une par libellé et
 * couleur, préparées hors du fil principal ; vide le temps de les dessiner.
 */
@Composable
private fun rememberMarkerImages(looks: List<MarkerLook>): Map<MarkerLook, ImageBitmap> {
    val isDark = isSystemInDarkTheme()
    val images by produceState(emptyMap<MarkerLook, ImageBitmap>(), looks, isDark) {
        value = withContext(Dispatchers.Default) {
            looks.associateWith { look ->
                val hex = AppColors.parkingAvailability(look.availability).hex(isDark)
                velovMarkerBitmap(look.label, hex, VelovForecastDemo.SHEET_FILTER).asImageBitmap()
            }
        }
    }
    return images
}

/**
 * Un marqueur de station. Quand [pop] change (une fourchette remplace un nombre, la couleur change), il
 * s'élargit en ressort, comme pour attirer l'œil sur ce qui vient de bouger.
 */
@Composable
private fun DemoMarker(image: ImageBitmap?, pop: Any, playback: Playback, modifier: Modifier = Modifier) {
    val spread = remember { Animatable(1f) }
    val shown = remember { mutableStateOf(pop) }
    LaunchedEffect(pop) {
        if (pop == shown.value) return@LaunchedEffect
        shown.value = pop
        if (playback.reduced) return@LaunchedEffect
        spread.snapTo(0f)
        spread.animateTo(1f, spring(dampingRatio = 0.4f, stiffness = Spring.StiffnessMediumLow))
    }
    Box(
        modifier = modifier.graphicsLayer {
            scaleX = 0.7f + 0.3f * spread.value
            scaleY = 0.9f + 0.1f * spread.value
        }
    ) {
        if (image != null) Image(image, contentDescription = null)
    }
}

// --- Le plan dessiné ---

/** Le plan vu dans une toile : le coin (0, 0) du plan des stations tombe sur [origin], une unité vaut [unit]. */
private class PlanFrame(private val origin: Offset, val unit: Size) {
    fun at(point: Offset): Offset = Offset(origin.x + point.x * unit.width, origin.y + point.y * unit.height)

    /** Le tracé qui relie [points], en ligne brisée, ou lissé (courbe de Catmull-Rom) avec [smooth]. */
    fun path(points: List<Offset>, smooth: Boolean): Path = Path().apply {
        val at = points.map(::at)
        moveTo(at.first().x, at.first().y)
        for (rank in 0 until at.lastIndex) {
            val (p1, p2) = at[rank] to at[rank + 1]
            if (!smooth) {
                lineTo(p2.x, p2.y)
                continue
            }
            val p0 = at[maxOf(rank - 1, 0)]
            val p3 = at[minOf(rank + 2, at.lastIndex)]
            cubicTo(
                p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
                p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6,
                p2.x, p2.y
            )
        }
    }
}

/** Comment une scène cadre le plan dans une toile de taille donnée. */
private fun interface PlanView {
    fun frame(density: Density, size: Size): PlanFrame
}

/** Un trait du plan : ses points, en coordonnées des stations, et sa largeur en part d'une unité du plan. */
private class PlanLine(val points: List<Offset>, val width: Float)

/**
 * La Saône et le Rhône, qui se rejoignent plus bas, sous le panneau du curseur : ils passent entre les
 * stations de la démonstration sans en couvrir aucune.
 */
private val Rivers = listOf(
    PlanLine(listOf(Offset(0.08f, -0.4f), Offset(0.15f, 0.05f), Offset(0.24f, 0.28f), Offset(0.33f, 0.5f), Offset(0.33f, 0.7f), Offset(0.3f, 0.95f), Offset(0.36f, 1.25f), Offset(0.48f, 1.7f)), 0.05f),
    PlanLine(listOf(Offset(1.02f, -0.4f), Offset(0.98f, 0.1f), Offset(0.97f, 0.32f), Offset(0.92f, 0.52f), Offset(0.74f, 0.68f), Offset(0.62f, 0.9f), Offset(0.56f, 1.2f), Offset(0.5f, 1.7f)), 0.072f)
)

/** Les rues, larges et étroites ; tracées par-dessus l'eau, elles font aussi les ponts. */
private val Streets = listOf(
    PlanLine(listOf(Offset(-0.4f, 0.3f), Offset(1.4f, 0.26f)), 0.024f),
    PlanLine(listOf(Offset(-0.4f, 0.535f), Offset(1.4f, 0.5f)), 0.024f),
    PlanLine(listOf(Offset(-0.4f, 0.76f), Offset(1.4f, 0.72f)), 0.024f),
    PlanLine(listOf(Offset(-0.4f, 0.92f), Offset(1.4f, 0.98f)), 0.024f),
    PlanLine(listOf(Offset(0.53f, -0.4f), Offset(0.5f, 1.7f)), 0.024f),
    PlanLine(listOf(Offset(0.22f, -0.4f), Offset(0.12f, 1.7f)), 0.024f),
    PlanLine(listOf(Offset(0.8f, -0.4f), Offset(0.84f, 1.7f)), 0.024f),
    PlanLine(listOf(Offset(-0.4f, 0.12f), Offset(1.4f, 0.08f)), 0.013f),
    PlanLine(listOf(Offset(-0.4f, 1.2f), Offset(1.4f, 1.16f)), 0.013f),
    PlanLine(listOf(Offset(0.66f, -0.4f), Offset(0.68f, 1.7f)), 0.013f),
    PlanLine(listOf(Offset(0.96f, -0.4f), Offset(0.92f, 1.7f)), 0.013f),
    PlanLine(listOf(Offset(0.36f, -0.4f), Offset(0.4f, 0.2f)), 0.013f),
    PlanLine(listOf(Offset(0f, 0f), Offset(1.2f, 1.5f)), 0.013f)
)

/** Le plan dessiné sous les stations : sol, Saône et Rhône, rues, cadrés par [view]. */
@Composable
private fun Modifier.demoPlan(view: PlanView): Modifier {
    val land = Tokens.introMapLand
    val street = Tokens.introMapStreet
    val water = Tokens.introMapWater
    return drawWithCache {
        val frame = view.frame(this, size)
        fun strokes(lines: List<PlanLine>, smooth: Boolean) = lines.map { line ->
            frame.path(line.points, smooth) to Stroke(width = frame.unit.width * line.width, cap = StrokeCap.Round, join = StrokeJoin.Round)
        }
        val rivers = strokes(Rivers, smooth = true)
        val streets = strokes(Streets, smooth = false)
        onDrawBehind {
            drawRect(land)
            rivers.forEach { (path, stroke) -> drawPath(path, water, style = stroke) }
            streets.forEach { (path, stroke) -> drawPath(path, street, style = stroke) }
        }
    }
}

/** Pose chaque enfant sur sa station ([points], dans l'ordre), le centre de son marqueur sur la station. */
@Composable
private fun PinLayer(view: PlanView, points: List<Offset>, content: @Composable () -> Unit) {
    Layout(content = content, modifier = Modifier.fillMaxSize()) { measurables, constraints ->
        val placeables = measurables.map { it.measure(Constraints()) }
        val frame = view.frame(this, Size(constraints.maxWidth.toFloat(), constraints.maxHeight.toFloat()))
        val anchor = MarkerHalfHeight.roundToPx()
        layout(constraints.maxWidth, constraints.maxHeight) {
            placeables.forEachIndexed { rank, placeable ->
                val at = frame.at(points[rank])
                placeable.place((at.x - placeable.width / 2f).roundToInt(), at.y.roundToInt() - anchor)
            }
        }
    }
}

// --- 2. Carte ---

/** Le plan de la page « carte » : les stations dans le haut de la scène, au-dessus du panneau du curseur. */
private val MapView = PlanView { density, size ->
    with(density) {
        val side = 30.dp.toPx()
        val top = 24.dp.toPx()
        PlanFrame(Offset(side, top), Size(size.width - 2 * side, size.height - top - 150.dp.toPx()))
    }
}

/**
 * Le plan et ses huit stations avec leurs vrais marqueurs, et en bas le panneau du curseur de la carte.
 * Un doigt fait glisser le pouce d'un arrêt à l'autre ; les marqueurs changent de chiffre et de couleur
 * sur son passage.
 */
@Composable
private fun MapScene(playback: Playback) {
    val thumb = remember { Animatable(0f) }
    val finger = remember { Animatable(0f) }
    Play(
        playback,
        rewind = {
            thumb.snapTo(0f)
            finger.snapTo(0f)
        },
        still = {
            thumb.snapTo(EVENING.toFloat())
            finger.snapTo(0f)
        },
        loop = {
            delay(700)
            (TOUR.drop(1) + TOUR.first()).forEach { stop -> slideThumb(thumb, finger, stop, hold = 650) }
        }
    )
    val step by remember { derivedStateOf { thumb.value.roundToInt() } }
    val images = rememberMarkerImages(DemoFrames.mapLooks)
    Box(modifier = Modifier.fillMaxSize().demoPlan(MapView)) {
        PinLayer(MapView, DemoFrames.points) {
            DemoFrames.markers[step].forEach { marker ->
                DemoMarker(images[marker.look], pop = (step == 0) to marker.availability, playback = playback)
            }
        }
        VelovTimePanel(
            panel = DemoFrames.mapPanels[step],
            step = { thumb.value },
            onStepChange = null,
            modifier = Modifier.align(Alignment.BottomCenter).padding(10.dp).fillMaxWidth(),
            finger = { finger.value }
        )
    }
}

// --- 3. Fourchette ---

/**
 * La carte de la fiche : le graphique des 24 heures se dessine de gauche à droite, puis le curseur le
 * parcourt ; à chaque arrêt, la lecture de la fiche défile et une accolade marque la fourchette.
 */
@Composable
private fun RangeScene(playback: Playback) {
    val reveal = remember { Animatable(0f) }
    val cursor = remember { Animatable(0f) }
    val brace = remember { Animatable(0f) }
    var stop by remember { mutableIntStateOf(0) }
    val readout = remember { derivedStateOf { DemoFrames.readouts[stop] } }
    Play(
        playback,
        rewind = {
            reveal.snapTo(0f)
            cursor.snapTo(0f)
            brace.snapTo(0f)
            stop = 0
        },
        still = {
            reveal.snapTo(1f)
            cursor.snapTo(EVENING.toFloat())
            brace.snapTo(1f)
            stop = EVENING
        },
        loop = {
            delay(300)
            reveal.animateTo(1f, tween(1300, easing = LinearOutSlowInEasing))
            delay(300)
            for (next in RANGE_TOUR) {
                brace.animateTo(0f, tween(120))
                cursor.animateTo(next.toFloat(), tween(600, easing = FastOutSlowInEasing))
                stop = next
                brace.animateTo(1f, tween(220))
                delay(850)
            }
            brace.animateTo(0f, tween(150))
            stop = 0
            coroutineScope {
                launch { cursor.animateTo(0f, tween(500, easing = FastOutLinearInEasing)) }
                reveal.animateTo(0f, tween(500, easing = FastOutLinearInEasing))
            }
        }
    )
    val panel = DemoFrames.panel
    Column(modifier = Modifier.fillMaxSize().padding(14.dp), verticalArrangement = Arrangement.Center) {
        VelovCard {
            VelovReadout(readout, rolls = !playback.reduced)
            Column {
                Box {
                    VelovForecastChart(panel, step = { cursor.value }, reveal = { reveal.value })
                    RangeBrace(panel, cursor = { cursor.value }, shown = { brace.value }, modifier = Modifier.matchParentSize())
                }
                VelovTimeTrack(
                    step = { cursor.value },
                    onStepChange = {},
                    description = { readout.value.time },
                    trackLevels = panel.trackLevels
                )
                VelovTickRow(panel.ticks)
            }
        }
    }
}

/** L'accolade posée à droite du curseur du graphique, du haut au bas de la fourchette écrite (déciles 10 et 90). */
@Composable
private fun RangeBrace(panel: VelovForecastPanel, cursor: () -> Float, shown: () -> Float, modifier: Modifier) {
    val color = MaterialTheme.colorScheme.onSurface
    Spacer(
        modifier = modifier.drawBehind {
            val opacity = shown()
            if (opacity <= 0f) return@drawBehind
            val frame = ChartFrame(this, size, panel.scaleMax)
            val point = panel.pointAt(cursor())
            val x = frame.x(point.position) + 9.dp.toPx()
            val top = frame.y(point.high)
            val bottom = frame.y(point.low)
            val curl = min(6.dp.toPx(), (bottom - top) / 4)
            val mid = (top + bottom) / 2
            val brace = Path().apply {
                moveTo(x, top)
                cubicTo(x + curl, top, x + curl, top, x + curl, top + curl)
                lineTo(x + curl, mid - curl)
                cubicTo(x + curl, mid, x + curl, mid, x + 2 * curl, mid)
                cubicTo(x + curl, mid, x + curl, mid, x + curl, mid + curl)
                lineTo(x + curl, bottom - curl)
                cubicTo(x + curl, bottom, x + curl, bottom, x, bottom)
            }
            drawPath(brace, color, alpha = opacity, style = Stroke(width = 1.8.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    )
}

// --- 4. Chances ---

/**
 * La jauge de la chance, à la couleur de son palier, et dessous la piste de couleur du curseur de la
 * fiche, dont le pouce avance : la jauge suit, et la période à risque apparaît quand il entre dans le rouge.
 */
@Composable
private fun ChanceScene(playback: Playback) {
    val thumb = remember { Animatable(MORNING.toFloat()) }
    var risky by remember { mutableStateOf(false) }
    fun unlikelyAt(step: Float) = DemoFrames.readouts[step.roundToInt()].chance?.level == VelovChanceLevel.UNLIKELY
    Play(
        playback,
        rewind = {
            thumb.snapTo(MORNING.toFloat())
            risky = false
        },
        still = {
            thumb.snapTo(EMPTY.toFloat())
            risky = true
        },
        loop = {
            delay(900)
            thumb.animateTo(EMPTY.toFloat(), tween(1300, easing = FastOutSlowInEasing)) { if (unlikelyAt(value)) risky = true }
            delay(1500)
            thumb.animateTo(NOON.toFloat(), tween(2200, easing = FastOutSlowInEasing))
            delay(1500)
            risky = false
            thumb.animateTo(MORNING.toFloat(), tween(700, easing = FastOutSlowInEasing))
            delay(400)
        }
    )
    val step by remember { derivedStateOf { thumb.value.roundToInt() } }
    val readout = DemoFrames.readouts[step]
    val riskIn by animateFloatAsState(if (risky) 1f else 0f, tween(380), label = "période à risque")
    val panel = DemoFrames.panel
    Column(
        modifier = Modifier.fillMaxSize().padding(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)
    ) {
        Rolling(readout.time, rolls = !playback.reduced) {
            Text(it, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
        }
        ChanceGauge(readout.chance, rolls = !playback.reduced, modifier = Modifier.size(196.dp))
        VelovCard {
            Column {
                VelovTimeTrack(
                    step = { thumb.value },
                    onStepChange = {},
                    description = { readout.time },
                    trackLevels = panel.trackLevels
                )
                VelovTickRow(panel.ticks)
            }
            panel.risk?.let { risk ->
                Box(
                    modifier = Modifier.graphicsLayer {
                        alpha = riskIn
                        translationY = (1f - riskIn) * 6.dp.toPx()
                    }
                ) { VelovRiskRow(risk) }
            }
        }
    }
}

/** La jauge circulaire : la part de la chance, sa couleur, et au centre le pourcentage et le palier, qui défilent. */
@Composable
private fun ChanceGauge(chance: VelovChance?, rolls: Boolean, modifier: Modifier) {
    val idle = MaterialTheme.colorScheme.outlineVariant
    val sweep by animateFloatAsState((chance?.percent ?: 0) / 100f, spring(stiffness = Spring.StiffnessLow), label = "jauge")
    val color by animateColorAsState(chance?.let { Tokens.velovChance(it.level) } ?: idle, tween(400), label = "couleur de la jauge")
    Box(
        modifier = modifier.drawBehind {
            val ring = 16.dp.toPx()
            val topLeft = Offset(ring / 2, ring / 2)
            val arcSize = Size(size.width - ring, size.height - ring)
            drawArc(idle, startAngle = 0f, sweepAngle = 360f, useCenter = false, topLeft = topLeft, size = arcSize, alpha = 0.4f, style = Stroke(width = ring))
            drawArc(
                color,
                startAngle = -90f,
                sweepAngle = 360f * sweep,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = ring, cap = StrokeCap.Round)
            )
        },
        contentAlignment = Alignment.Center
    ) {
        Rolling(chance, rolls, alignment = Alignment.Center) { shown ->
            if (shown != null) {
                val tint = Tokens.velovChance(shown.level)
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(shown.text, fontSize = 46.sp, fontWeight = FontWeight.Bold, color = tint, maxLines = 1)
                    Text(shown.level.label, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = tint, maxLines = 1)
                }
            }
        }
    }
}
