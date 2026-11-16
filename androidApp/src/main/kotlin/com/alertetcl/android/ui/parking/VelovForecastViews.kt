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
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import com.alertetcl.shared.models.VelovForecastNeighbour
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
    var step by rememberSaveable { mutableIntStateOf(initialStep) }
    val readout = forecast?.let { remember(it, filter, step) { it.readout(filter, step) } }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        VelovCard {
            VelovFilterBar(filter, onFilter, Modifier.padding(horizontal = AxisInset).fillMaxWidth(), onMap = false)
            if (forecast == null || readout == null) {
                Spacer(Modifier.height(ChartHeight))
            } else {
                VelovForecastReadings(forecast.panel(filter), readout, onStepChange = { step = it })
            }
        }
        if (readout != null && readout.saferNearby.isNotEmpty()) {
            VelovSaferNearby(readout.saferNearby, onOpenStation)
        }
    }
}

/** Carte de la fiche : une surface discrète, sans marge horizontale pour que le graphique aille d'un bord à l'autre. */
@Composable
private fun VelovCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

/** Ce qui est prévu à l'échéance du curseur, le graphique des 24 heures, le curseur et la période à risque. */
@Composable
private fun VelovForecastReadings(panel: VelovForecastPanel, readout: VelovForecastReadout, onStepChange: (Int) -> Unit) {
    VelovReadout(readout)
    // Le graphique, la piste et les repères partagent le même axe : glisser sur l'un ou l'autre déplace le curseur.
    Column(modifier = Modifier.timeScrub(readout.step, onStepChange)) {
        VelovForecastChart(panel, readout.step)
        VelovTimeTrack(readout.step, onStepChange, description = "${readout.time}, ${readout.count}", trackLevels = panel.trackLevels)
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
private fun VelovReadout(readout: VelovForecastReadout) {
    val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    Row(
        modifier = Modifier.padding(horizontal = AxisInset).fillMaxWidth(),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(readout.time, style = MaterialTheme.typography.labelLarge, color = secondary, maxLines = 1)
            // Même règle que les numéros de ligne : une seule ligne, qui rapetisse plutôt que d'être coupée.
            LineNumberText(readout.count, color = MaterialTheme.colorScheme.onSurface, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Text(readout.reliability.orEmpty(), style = MaterialTheme.typography.bodySmall, color = secondary, maxLines = 1)
        }
        readout.chance?.let { chance ->
            val color = Tokens.velovChance(chance.level)
            Column(horizontalAlignment = Alignment.End) {
                Text(chance.text, fontSize = 30.sp, fontWeight = FontWeight.Bold, color = color, maxLines = 1)
                Text(chance.level.label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = color, maxLines = 1)
            }
        }
    }
}

/**
 * Graphique des 24 heures : la valeur la plus probable (trait), la fourchette 10-90 (bande claire) et la
 * fourchette 30-70 (bande soutenue), à l'accent, sur une échelle de 0 à [VelovForecastPanel.scaleMax],
 * seul nombre écrit. Un trait pointillé marque minuit ; le curseur montre l'échéance [step].
 */
@Composable
private fun VelovForecastChart(panel: VelovForecastPanel, step: Int) {
    val accent = Tokens.accent
    val rule = MaterialTheme.colorScheme.outlineVariant
    val cursor = MaterialTheme.colorScheme.onSurface
    val dot = MaterialTheme.colorScheme.surface
    val labelStyle = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val measurer = rememberTextMeasurer()
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(ChartHeight)
            .semantics { contentDescription = VelovTexts.CHART_LABEL }
    ) {
        val top = 10.dp.toPx()
        val bottom = size.height - 6.dp.toPx()
        val left = axisX(0f, size.width)
        val right = axisX(1f, size.width)
        fun x(position: Double): Float = axisX(position.toFloat(), size.width)
        fun y(count: Double): Float = bottom - (count / panel.scaleMax).toFloat() * (bottom - top)

        // Tracé d'une courbe d'un bout à l'autre ; avec [back], la bande refermée entre les deux courbes.
        fun outline(
            forward: (VelovForecastChartPoint) -> Double,
            back: ((VelovForecastChartPoint) -> Double)? = null
        ): Path = Path().apply {
            panel.points.forEachIndexed { rank, point ->
                if (rank == 0) moveTo(x(point.position), y(forward(point))) else lineTo(x(point.position), y(forward(point)))
            }
            if (back != null) {
                panel.points.asReversed().forEach { point -> lineTo(x(point.position), y(back(point))) }
                close()
            }
        }

        // Échelle : le zéro, le haut de l'axe et son nombre.
        drawLine(rule, Offset(left, bottom), Offset(right, bottom), strokeWidth = 1.dp.toPx())
        drawLine(rule, Offset(left, top), Offset(right, top), strokeWidth = 1.dp.toPx())
        val scale = measurer.measure(panel.scaleMax.toString(), labelStyle)
        drawText(scale, topLeft = Offset(right - scale.size.width, top + 2.dp.toPx()))

        // Minuit et le jour qui commence, écrit à droite du trait, ou à gauche s'il buterait sur le nombre de l'échelle.
        panel.midnight?.let { midnight ->
            val at = x(midnight.position)
            drawLine(
                rule, Offset(at, top), Offset(at, bottom), strokeWidth = 1.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 3.dp.toPx()))
            )
            val day = measurer.measure(midnight.label, labelStyle)
            val gap = 5.dp.toPx()
            val fits = at + gap + day.size.width <= right - scale.size.width - gap
            drawText(day, topLeft = Offset(if (fits) at + gap else at - gap - day.size.width, top + 2.dp.toPx()))
        }

        drawPath(outline(VelovForecastChartPoint::high, VelovForecastChartPoint::low), accent, alpha = 0.16f)
        drawPath(outline(VelovForecastChartPoint::midHigh, VelovForecastChartPoint::midLow), accent, alpha = 0.30f)
        drawPath(
            outline(VelovForecastChartPoint::median), accent,
            style = Stroke(width = 2.4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
        )

        // Curseur : un trait qui descend jusqu'au pouce de la piste, la fourchette de l'échéance en gras
        // (réduite à un point à la première, qui est l'état réel) et la valeur la plus probable.
        val point = panel.points.getOrNull(step) ?: return@Canvas
        val at = x(point.position)
        val median = Offset(at, y(point.median))
        drawLine(cursor, Offset(at, top), Offset(at, size.height), strokeWidth = 1.5.dp.toPx())
        drawLine(accent, Offset(at, y(point.high)), Offset(at, y(point.low)), strokeWidth = 7.dp.toPx(), cap = StrokeCap.Round)
        drawCircle(dot, radius = 5.5.dp.toPx(), center = median)
        drawCircle(accent, radius = 5.5.dp.toPx(), center = median, style = Stroke(width = 3.dp.toPx()))
    }
}

/**
 * Fait suivre le doigt au curseur d'heure sur tout ce qui est posé sur l'axe (graphique, piste, repères) :
 * un toucher ou un glissement horizontal choisit l'échéance sous le doigt. Un glissement vertical reste
 * à la feuille, qui défile ou se referme.
 */
@Composable
private fun Modifier.timeScrub(step: Int, onStepChange: (Int) -> Unit): Modifier {
    val shown by rememberUpdatedState(step)
    val onStep by rememberUpdatedState(onStepChange)
    fun PointerInputScope.moveTo(x: Float) {
        val target = stepAt(x, size.width.toFloat())
        if (target != shown) onStep(target)
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
 * entendent [description].
 */
@Composable
private fun VelovTimeTrack(
    step: Int,
    onStepChange: (Int) -> Unit,
    description: String,
    trackLevels: List<VelovChanceLevel>? = null
) {
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
                stateDescription = description
                progressBarRangeInfo = ProgressBarRangeInfo(
                    current = step.toFloat(),
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
        val thumbX = axisX(step.toFloat() / VelovForecast.STEP_COUNT, size.width)
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

/** « Plus sûr à côté » : les stations voisines où la chance est bonne à la même échéance ; en toucher une ouvre sa fiche. */
@Composable
private fun VelovSaferNearby(neighbours: List<VelovForecastNeighbour>, onOpenStation: (VelovStation) -> Unit) {
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
 * Panneau de verre posé en bas de la carte des stations : l'heure regardée, le curseur qui la choisit et,
 * dès qu'il a bougé, le bouton qui ramène à l'état réel. Pas de légende : les couleurs sont celles des
 * marqueurs de toujours.
 */
@Composable
fun VelovTimePanel(panel: VelovForecastMapPanel, step: Int, onStepChange: (Int) -> Unit, modifier: Modifier = Modifier) {
    val accent = Tokens.accent
    Column(
        modifier = modifier
            .glass(RoundedCornerShape(26.dp), alpha = 0.86f)
            // Un geste commencé sur le panneau ne déplace pas la carte qui est dessous.
            .pointerInput(Unit) { detectTapGestures { } }
            .padding(top = 10.dp, bottom = 12.dp)
    ) {
        Row(modifier = Modifier.padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(panel.title, fontSize = 19.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                // La ligne garde sa place quand la consigne s'efface : le panneau ne change pas de hauteur sous le doigt.
                Text(panel.hint.orEmpty(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
            panel.nowButton?.let { label ->
                TextButton(
                    onClick = { onStepChange(0) },
                    colors = ButtonDefaults.textButtonColors(containerColor = accent.copy(alpha = 0.12f), contentColor = accent)
                ) {
                    Text(label, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        // La marge de l'axe (16 dp) plus 2 dp : le pouce s'aligne sur le texte du panneau.
        Column(modifier = Modifier.padding(horizontal = 2.dp).timeScrub(step, onStepChange)) {
            VelovTimeTrack(step, onStepChange, description = panel.title)
            VelovTickRow(panel.ticks)
        }
    }
}
