package com.alertetcl.android.ui.parking

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableIntState
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.structuralEqualityPolicy
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.components.LineNumberText
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.VelovChanceLevel
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovForecast
import com.alertetcl.shared.models.VelovForecastChartPoint
import com.alertetcl.shared.models.VelovForecastMapPanel
import com.alertetcl.shared.models.VelovForecastPanel
import com.alertetcl.shared.models.VelovForecastReadout
import com.alertetcl.shared.models.VelovForecastSheet
import com.alertetcl.shared.models.VelovForecastTick
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.models.VelovTexts
import kotlin.math.roundToInt

// Prévision Vélo'v à l'écran : le bloc de la fiche d'une station (graphique des 24 heures et son curseur)
// et le panneau du curseur d'heure de la carte. Textes, nombres et paliers viennent du module partagé
// (`VelovForecastSheet`, `VelovForecastMapPanel`) ; ce fichier ne calcule que de la géométrie.
//
// Pour que le curseur suive le doigt, l'échéance n'est lue que par ce qui en dépend : le chiffre, la
// piste et « Plus sûr à côté » se recomposent à chaque cran, le curseur du graphique se redessine seul
// sur sa propre couche, et les courbes ne sont tracées qu'une fois par filtre et par taille.

/**
 * Marge de chaque côté de l'axe des heures, commune au graphique, à la piste du curseur et aux repères :
 * une échéance tombe à la même abscisse sur les trois, et le pouce, plus étroit que la marge, ne dépasse
 * pas du graphique à la première ni à la dernière échéance. C'est aussi la marge du texte de la fiche.
 */
private val AxisInset = 16.dp
private val ChartHeight = 190.dp
private val ThumbRadius = 13.dp
private val TrackThickness = 8.dp

/** Largeur utile de l'axe des heures dans une largeur de [width] pixels. */
private fun Density.axisSpan(width: Float): Float = (width - 2 * AxisInset.toPx()).coerceAtLeast(1f)

/** Abscisse d'une place sur l'axe des heures, de 0 (maintenant) à 1 (dernière échéance). */
private fun Density.axisX(position: Float, width: Float): Float = AxisInset.toPx() + position * axisSpan(width)

/** L'échéance la plus proche de l'abscisse [x] : l'inverse de [axisX]. */
private fun Density.stepAt(x: Float, width: Float): Int {
    val position = ((x - AxisInset.toPx()) / axisSpan(width)).coerceIn(0f, 1f)
    return (position * VelovForecast.STEP_COUNT).roundToInt()
}

/**
 * Ce que la fiche d'une station montre de sa prévision : la carte du graphique, puis « Plus sûr à côté »
 * quand il y a lieu. [forecast] est null le temps du calcul : la place du graphique est alors gardée.
 * Le curseur part de [initialStep], l'échéance de la carte à l'ouverture, et reste où il est quand la
 * fiche passe à une station voisine.
 */
@Composable
fun VelovForecastSection(
    forecast: VelovForecastSheet?,
    filter: VelovFilter,
    onFilter: (VelovFilter) -> Unit,
    initialStep: Int,
    onOpenStation: (VelovStation) -> Unit
) {
    val step = rememberSaveable { mutableIntStateOf(initialStep) }
    // Ce qui est prévu à l'échéance du curseur, calculé une fois par cran et lu seulement par ce qui l'affiche.
    val readout = forecast?.let { sheet -> remember(sheet, filter) { derivedStateOf { sheet.readout(filter, step.intValue) } } }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        VelovCard {
            VelovFilterBar(filter, onFilter, Modifier.padding(horizontal = AxisInset).fillMaxWidth(), onMap = false)
            if (forecast == null || readout == null) {
                Spacer(Modifier.height(ChartHeight))
            } else {
                VelovForecastReadings(remember(forecast, filter) { forecast.panel(filter) }, readout, step)
            }
        }
        if (readout != null) VelovSaferNearby(readout, onOpenStation)
    }
}

/** Carte de la fiche : une surface discrète, sans marge horizontale pour que le graphique aille d'un bord à l'autre. */
@Composable
internal fun VelovCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

/**
 * Ce qui est prévu à l'échéance du curseur, le graphique des 24 heures, le curseur et la période à
 * risque. Ne lit pas l'échéance elle-même : il ne se recompose pas quand le curseur glisse.
 */
@Composable
private fun VelovForecastReadings(panel: VelovForecastPanel, readout: State<VelovForecastReadout>, step: MutableIntState) {
    val shown = { step.intValue }
    val move = { target: Int -> step.intValue = target }
    VelovReadout(readout)
    // Le graphique, la piste et les repères partagent le même axe : glisser sur l'un ou l'autre déplace le curseur.
    Column(modifier = Modifier.timeScrub(shown, move)) {
        VelovForecastChart(panel, shown)
        VelovTimeTrack(
            step = shown,
            onStepChange = move,
            description = { readout.value.let { "${it.time}, ${it.count}" } },
            trackLevels = panel.trackLevels
        )
        VelovTickRow(panel.ticks)
    }
    panel.risk?.let { risk ->
        HorizontalDivider(modifier = Modifier.padding(horizontal = AxisInset))
        Row(
            modifier = Modifier.padding(horizontal = AxisInset),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(modifier = Modifier.size(8.dp).background(Tokens.error, CircleShape))
            Text(risk, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

/**
 * L'heure de l'échéance, le chiffre principal et sa fiabilité ; en face, la chance et son palier dans la
 * couleur du palier. Les lignes gardent leur place même vides (échéance « maintenant ») : le graphique
 * ne bouge pas sous le doigt quand le curseur quitte la première échéance.
 */
@Composable
private fun VelovReadout(readout: State<VelovForecastReadout>) {
    val shown = readout.value
    val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    Row(
        modifier = Modifier.padding(horizontal = AxisInset).fillMaxWidth(),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(shown.time, style = MaterialTheme.typography.labelLarge, color = secondary, maxLines = 1)
            // Même règle que les numéros de ligne : une seule ligne, qui rapetisse plutôt que d'être coupée.
            LineNumberText(shown.count, color = MaterialTheme.colorScheme.onSurface, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Text(shown.reliability.orEmpty(), style = MaterialTheme.typography.bodySmall, color = secondary, maxLines = 1)
        }
        shown.chance?.let { chance ->
            val color = Tokens.velovChance(chance.level)
            Column(horizontalAlignment = Alignment.End) {
                Text(chance.text, fontSize = 30.sp, fontWeight = FontWeight.Bold, color = color, maxLines = 1)
                Text(chance.level.label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = color, maxLines = 1)
            }
        }
    }
}

/** Le cadre du graphique dans une surface de [size] : bords de l'échelle et place de chaque point sur les deux axes. */
private class ChartFrame(private val density: Density, private val size: Size, private val scaleMax: Int) {
    val top = with(density) { 10.dp.toPx() }
    val bottom = size.height - with(density) { 6.dp.toPx() }
    val left = density.axisX(0f, size.width)
    val right = density.axisX(1f, size.width)

    fun x(position: Double): Float = density.axisX(position.toFloat(), size.width)
    fun y(count: Double): Float = bottom - (count / scaleMax).toFloat() * (bottom - top)

    /** Tracé d'une courbe d'un bout à l'autre ; avec [back], la bande refermée entre les deux courbes. */
    fun outline(
        points: List<VelovForecastChartPoint>,
        forward: (VelovForecastChartPoint) -> Double,
        back: ((VelovForecastChartPoint) -> Double)? = null
    ): Path = Path().apply {
        points.forEachIndexed { rank, point ->
            if (rank == 0) moveTo(x(point.position), y(forward(point))) else lineTo(x(point.position), y(forward(point)))
        }
        if (back != null) {
            points.asReversed().forEach { point -> lineTo(x(point.position), y(back(point))) }
            close()
        }
    }
}

/**
 * Graphique des 24 heures : la valeur la plus probable (trait), la fourchette 10-90 (bande claire) et la
 * fourchette 30-70 (bande soutenue), à l'accent, sur une échelle de 0 à [VelovForecastPanel.scaleMax],
 * seul nombre écrit. Un trait pointillé marque minuit ; le curseur montre l'échéance [step].
 *
 * Deux couches : le fond (échelle, minuit, bandes et trait), tracé une fois par panneau et par taille, et
 * le curseur, sur sa propre couche, qui lit l'échéance au moment de dessiner : seul lui se redessine
 * quand le curseur glisse.
 */
@Composable
private fun VelovForecastChart(panel: VelovForecastPanel, step: () -> Int) {
    val accent = Tokens.accent
    val rule = MaterialTheme.colorScheme.outlineVariant
    val cursor = MaterialTheme.colorScheme.onSurface
    val dot = MaterialTheme.colorScheme.surface
    val labelStyle = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val measurer = rememberTextMeasurer()
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(ChartHeight)
            .semantics { contentDescription = VelovTexts.CHART_LABEL }
    ) {
        Spacer(
            modifier = Modifier.matchParentSize().drawWithCache {
                val frame = ChartFrame(this, size, panel.scaleMax)
                val wide = frame.outline(panel.points, VelovForecastChartPoint::high, VelovForecastChartPoint::low)
                val core = frame.outline(panel.points, VelovForecastChartPoint::midHigh, VelovForecastChartPoint::midLow)
                val median = frame.outline(panel.points, VelovForecastChartPoint::median)
                val medianStroke = Stroke(width = 2.4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
                val hairline = 1.dp.toPx()
                val labelTop = frame.top + 2.dp.toPx()
                val scale = measurer.measure(panel.scaleMax.toString(), labelStyle)
                // Minuit et le jour qui commence, écrit à droite du trait, ou à gauche s'il buterait sur le nombre de l'échelle.
                val midnight = panel.midnight?.let { tick ->
                    val at = frame.x(tick.position)
                    val day = measurer.measure(tick.label, labelStyle)
                    val gap = 5.dp.toPx()
                    val fits = at + gap + day.size.width <= frame.right - scale.size.width - gap
                    Triple(at, day, if (fits) at + gap else at - gap - day.size.width)
                }
                val dash = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 3.dp.toPx()))
                onDrawBehind {
                    // Échelle : le zéro, le haut de l'axe et son nombre.
                    drawLine(rule, Offset(frame.left, frame.bottom), Offset(frame.right, frame.bottom), strokeWidth = hairline)
                    drawLine(rule, Offset(frame.left, frame.top), Offset(frame.right, frame.top), strokeWidth = hairline)
                    drawText(scale, topLeft = Offset(frame.right - scale.size.width, labelTop))
                    midnight?.let { (at, day, dayX) ->
                        drawLine(rule, Offset(at, frame.top), Offset(at, frame.bottom), strokeWidth = hairline, pathEffect = dash)
                        drawText(day, topLeft = Offset(dayX, labelTop))
                    }
                    drawPath(wide, accent, alpha = 0.16f)
                    drawPath(core, accent, alpha = 0.30f)
                    drawPath(median, accent, style = medianStroke)
                }
            }
        )
        // Curseur : un trait qui descend jusqu'au pouce de la piste, la fourchette de l'échéance en gras
        // (réduite à un point à la première, qui est l'état réel) et la valeur la plus probable.
        Spacer(
            modifier = Modifier.matchParentSize().graphicsLayer { }.drawBehind {
                val point = panel.points.getOrNull(step()) ?: return@drawBehind
                val frame = ChartFrame(this, size, panel.scaleMax)
                val at = frame.x(point.position)
                val center = Offset(at, frame.y(point.median))
                drawLine(cursor, Offset(at, frame.top), Offset(at, size.height), strokeWidth = 1.5.dp.toPx())
                drawLine(accent, Offset(at, frame.y(point.high)), Offset(at, frame.y(point.low)), strokeWidth = 7.dp.toPx(), cap = StrokeCap.Round)
                drawCircle(dot, radius = 5.5.dp.toPx(), center = center)
                drawCircle(accent, radius = 5.5.dp.toPx(), center = center, style = Stroke(width = 3.dp.toPx()))
            }
        )
    }
}

/**
 * Fait suivre le doigt au curseur d'heure sur tout ce qui est posé sur l'axe (graphique, piste, repères) :
 * un toucher ou un glissement horizontal choisit l'échéance sous le doigt. Un glissement vertical reste
 * à la feuille, qui défile ou se referme.
 */
@Composable
private fun Modifier.timeScrub(step: () -> Int, onStepChange: (Int) -> Unit): Modifier {
    val shown by rememberUpdatedState(step)
    val onStep by rememberUpdatedState(onStepChange)
    fun PointerInputScope.moveTo(x: Float) {
        val target = stepAt(x, size.width.toFloat())
        if (target != shown()) onStep(target)
    }
    return this
        .pointerInput(Unit) { detectTapGestures(onTap = { moveTo(it.x) }) }
        .pointerInput(Unit) {
            detectHorizontalDragGestures { change, _ ->
                change.consume()
                moveTo(change.position.x)
            }
        }
}

/**
 * Piste et pouce du curseur d'heure, de « maintenant » à la dernière échéance, un cran par quart d'heure.
 * Dessinés ici plutôt qu'avec le `Slider` de Material : la piste de la fiche prend la couleur du palier
 * de chaque échéance ([trackLevels]), et le pouce doit tomber exactement sous le curseur du graphique.
 * Sans paliers (carte), la piste est neutre et remplie à l'accent jusqu'au pouce. Les gestes viennent de
 * [timeScrub], posé par l'appelant ; les lecteurs d'écran règlent l'échéance par [onStepChange] et
 * entendent [description]. L'échéance est lue ici : à chaque cran, seule la piste se recompose.
 */
@Composable
private fun VelovTimeTrack(
    step: () -> Int,
    onStepChange: (Int) -> Unit,
    description: () -> String,
    trackLevels: List<VelovChanceLevel>? = null
) {
    val current = step()
    val accent = Tokens.accent
    val idle = MaterialTheme.colorScheme.outlineVariant
    val trackColors = trackLevels?.let { levels ->
        val byLevel = VelovChanceLevel.entries.associateWith { Tokens.velovChanceTrack(it) }
        levels.map { byLevel.getValue(it) }
    }
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(ThumbRadius * 2 + 6.dp)
            .semantics {
                contentDescription = VelovTexts.SLIDER_LABEL
                stateDescription = description()
                progressBarRangeInfo = ProgressBarRangeInfo(
                    current = current.toFloat(),
                    range = 0f..VelovForecast.STEP_COUNT.toFloat(),
                    steps = VelovForecast.STEP_COUNT - 1
                )
                setProgress { target ->
                    onStepChange(target.roundToInt().coerceIn(0, VelovForecast.STEP_COUNT))
                    true
                }
            }
    ) {
        val centerY = size.height / 2
        val thickness = TrackThickness.toPx()
        val left = axisX(0f, size.width)
        val bar = Rect(left, centerY - thickness / 2, axisX(1f, size.width), centerY + thickness / 2)
        val thumbX = axisX(current.toFloat() / VelovForecast.STEP_COUNT, size.width)
        clipPath(Path().apply { addRoundRect(RoundRect(bar, CornerRadius(thickness / 2))) }) {
            if (trackColors == null) {
                drawRect(idle, bar.topLeft, bar.size)
                drawRect(accent, bar.topLeft, Size(thumbX - left, bar.height))
            } else {
                // Le segment de rang i va de l'échéance i à la suivante ; les voisins de même couleur
                // sont peints d'un seul tenant, sans liseré entre eux.
                var from = 0
                while (from < trackColors.size) {
                    var to = from + 1
                    while (to < trackColors.size && trackColors[to] == trackColors[from]) to++
                    val start = axisX(from.toFloat() / VelovForecast.STEP_COUNT, size.width)
                    val end = axisX(to.toFloat() / VelovForecast.STEP_COUNT, size.width)
                    drawRect(trackColors[from], Offset(start, bar.top), Size(end - start, bar.height))
                    from = to
                }
            }
        }
        // Pouce blanc sur les deux thèmes, détaché de la piste par une ombre portée.
        val radius = ThumbRadius.toPx()
        drawCircle(Color.Black.copy(alpha = 0.2f), radius = radius + 1.dp.toPx(), center = Offset(thumbX, centerY + 1.dp.toPx()))
        drawCircle(Color.White, radius = radius, center = Offset(thumbX, centerY))
    }
}

/** Heures écrites sous la piste, chacune centrée sur sa place de l'axe sans sortir de la largeur. */
@Composable
private fun VelovTickRow(ticks: List<VelovForecastTick>) {
    val color = MaterialTheme.colorScheme.onSurfaceVariant
    Layout(
        content = { ticks.forEach { Text(it.label, style = MaterialTheme.typography.labelSmall, color = color, maxLines = 1) } },
        // Repères visuels seulement : l'heure choisie est dite par la piste.
        modifier = Modifier.fillMaxWidth().clearAndSetSemantics { }
    ) { measurables, constraints ->
        val labels = measurables.map { it.measure(Constraints()) }
        val width = constraints.maxWidth
        layout(width, labels.maxOfOrNull { it.height } ?: 0) {
            labels.forEachIndexed { rank, label ->
                val center = axisX(ticks[rank].position.toFloat(), width.toFloat())
                label.place((center - label.width / 2f).roundToInt().coerceIn(0, (width - label.width).coerceAtLeast(0)), 0)
            }
        }
    }
}

/**
 * « Plus sûr à côté » : les stations voisines où la chance est bonne à la même échéance ; en toucher une
 * ouvre sa fiche. Ne se recompose que quand la liste change, pas à chaque cran du curseur.
 */
@Composable
private fun VelovSaferNearby(readout: State<VelovForecastReadout>, onOpenStation: (VelovStation) -> Unit) {
    val neighbours by remember(readout) { derivedStateOf(structuralEqualityPolicy()) { readout.value.saferNearby } }
    if (neighbours.isEmpty()) return
    VelovCard {
        Text(
            VelovForecastSheet.SAFER_NEARBY_TITLE,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = AxisInset)
        )
        Column {
            neighbours.forEachIndexed { rank, neighbour ->
                if (rank > 0) HorizontalDivider(modifier = Modifier.padding(horizontal = AxisInset))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenStation(neighbour.station) }
                        .padding(horizontal = AxisInset, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(neighbour.station.displayName, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                        Text(neighbour.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text(
                        neighbour.chance.text,
                        fontSize = 19.sp,
                        fontWeight = FontWeight.Bold,
                        color = Tokens.velovChance(neighbour.chance.level),
                        maxLines = 1
                    )
                }
            }
        }
    }
}

/**
 * Panneau de verre posé en bas de la carte des stations : l'heure regardée et le curseur qui la choisit.
 * Pas de bouton pour revenir à « Maintenant » : on y revient en glissant. Pas de légende : les couleurs
 * sont celles des marqueurs de toujours.
 */
@Composable
fun VelovTimePanel(panel: VelovForecastMapPanel, step: Int, onStepChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .glass(RoundedCornerShape(26.dp), alpha = 0.86f)
            // Un geste commencé sur le panneau ne déplace pas la carte qui est dessous.
            .pointerInput(Unit) { detectTapGestures { } }
            .padding(top = 10.dp, bottom = 12.dp)
    ) {
        Column(modifier = Modifier.padding(horizontal = 18.dp)) {
            Text(panel.title, fontSize = 19.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            // La ligne garde sa place quand la consigne s'efface : le panneau ne change pas de hauteur sous le doigt.
            Text(panel.hint.orEmpty(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
        }
        // La marge de l'axe (16 dp) plus 2 dp : le pouce s'aligne sur le texte du panneau.
        Column(modifier = Modifier.padding(horizontal = 2.dp).timeScrub({ step }, onStepChange)) {
            VelovTimeTrack(step = { step }, onStepChange = onStepChange, description = { panel.title })
            VelovTickRow(panel.ticks)
        }
    }
}
