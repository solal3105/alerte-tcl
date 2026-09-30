package com.alertetcl.android.ui.live

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.android.ui.components.LineBadge
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.LineBoard
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.PassagePhase
import com.alertetcl.shared.models.PassageStatus
import com.alertetcl.shared.models.PassageTexts
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.models.Vehicle
import com.alertetcl.shared.models.VehicleType

/** Nombre d'arrêts dessinés au plus sur la mini-ligne ; au-delà, elle commence par « … ». */
private const val MINI_LINE_STOPS = 3

internal fun vehicleTypeIcon(type: VehicleType): ImageVector = when (type) {
    VehicleType.BUS, VehicleType.TROLLEY -> Icons.Filled.DirectionsBus
    else -> Icons.Filled.Tram
}

/**
 * Un sens d'une ligne à l'arrêt, en une carte : le prochain passage en gros (délai ou état, jamais une
 * heure passée), où est le véhicule sur une mini-ligne, puis « Ensuite … · dernier … ». Tout vient de
 * [LineBoard] ([com.alertetcl.shared.models.StopBoard]) recalculé chaque seconde avec [nowMs].
 */
@Composable
internal fun LineBoardCard(
    board: LineBoard,
    nowMs: Long,
    /** Fiche horaire connue : sans passage, on sait alors que rien n'est prévu. */
    timetableKnown: Boolean,
    onLocate: (PassageStatus) -> Unit,
    onShowOnMap: () -> Unit,
    onShowTimetable: () -> Unit
) {
    val group = board.group
    val first = board.first
    Surface(shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surfaceContainer, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(start = 14.dp, end = 4.dp, top = 6.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LineBadge(group.line, size = 30.dp)
                Text(group.terminus, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                TransportMode.detectFromLine(group.line).showOnMapLabel?.let { label ->
                    IconButton(onClick = onShowOnMap) { Icon(Icons.Filled.Map, label, tint = Tokens.accent, modifier = Modifier.size(20.dp)) }
                }
                IconButton(onClick = onShowTimetable) { Icon(Icons.Filled.CalendarMonth, "Tous les horaires", tint = Tokens.accent, modifier = Modifier.size(20.dp)) }
            }
            Column(modifier = Modifier.padding(end = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                if (first == null) {
                    Text(
                        if (timetableKnown) PassageTexts.NONE_PLANNED else PassageTexts.NONE_ANNOUNCED,
                        style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    return@Column
                }
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PassageHeadline(first, nowMs, fontSize = 28.sp)
                    val detail = listOfNotNull(
                        first.caption(nowMs),
                        first.shortDestination?.let { "jusqu'à $it" },
                        PassageTexts.LAST_OF_DAY.takeIf { board.firstIsLast }
                    ).joinToString(" · ")
                    if (detail.isNotEmpty()) {
                        Text(detail, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1,
                            overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(bottom = 4.dp))
                    }
                }
                first.approach?.let { approach ->
                    Column(
                        modifier = Modifier.fillMaxWidth().clickable { onLocate(first) }.padding(vertical = 2.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        MiniLine(
                            stopsBefore = approach.stopsBefore,
                            atStop = first.phase == PassagePhase.AT_STOP,
                            lineColor = colorFromHex(LineColors.backgroundHex(group.line)),
                            vehicleIcon = vehicleTypeIcon(approach.vehicle.vehicleType)
                        )
                        VehicleStatusLines(first.location, approach.vehicle, nowMs)
                    }
                }
                PassageTexts.thenLine(board)?.let {
                    Text(it, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

/**
 * Le gros texte d'un passage précédé de sa source : point vert qui pulse pour le direct, horloge grise
 * pour l'horaire prévu. Le même rendu sert à la fiche d'arrêt et à la fiche horaire.
 */
@Composable
internal fun PassageHeadline(status: PassageStatus, nowMs: Long, fontSize: TextUnit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (status.phase.isLive) LiveDot() else Icon(
            Icons.Outlined.Schedule, "Horaire prévu", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp)
        )
        Text(
            status.headline(nowMs), fontSize = fontSize, fontWeight = FontWeight.Bold, maxLines = 1,
            color = if (status.phase.isLive) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

/**
 * Une phrase sur un véhicule, [lead] (où il est) puis sa ponctualité, en orange seulement quand il
 * s'écarte de l'horaire ; dessous, en gris, l'âge de sa position quand elle date. Carte d'un passage
 * et bandeau d'un véhicule touché sur la carte.
 */
@Composable
internal fun VehicleStatusLines(lead: String?, vehicle: Vehicle, nowMs: Long) {
    val deviates = vehicle.isDelayed || vehicle.isEarly
    val neutral = MaterialTheme.colorScheme.onSurfaceVariant
    val warning = Tokens.warning
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            buildAnnotatedString {
                lead?.let { append(it); append(" · ") }
                withStyle(SpanStyle(color = if (deviates) warning else neutral, fontWeight = if (deviates) FontWeight.SemiBold else FontWeight.Normal)) {
                    append(vehicle.delayText)
                }
            },
            fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface, maxLines = 2
        )
        vehicle.stalenessLine(nowMs)?.let { Text(it, fontSize = 12.sp, color = MaterialTheme.colorScheme.outline) }
    }
}

/** Point vert qui pulse : passage suivi en direct. */
@Composable
private fun LiveDot() {
    val pulse by rememberInfiniteTransition(label = "direct").animateFloat(
        initialValue = 1f, targetValue = 0.35f,
        animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "direct"
    )
    Box(Modifier.size(9.dp).alpha(pulse).background(Tokens.success, CircleShape))
}

/**
 * Où est le véhicule : les derniers arrêts avant celui de l'usager (le plus gros, à droite), le
 * véhicule devant le prochain qu'il dessert, ou sur l'arrêt de l'usager quand il y est.
 */
@Composable
private fun MiniLine(stopsBefore: Int, atStop: Boolean, lineColor: Color, vehicleIcon: ImageVector) {
    val shown = minOf(stopsBefore, MINI_LINE_STOPS)
    Row(modifier = Modifier.fillMaxWidth().height(22.dp), verticalAlignment = Alignment.CenterVertically) {
        if (stopsBefore > MINI_LINE_STOPS) Text("…", color = MaterialTheme.colorScheme.outline, modifier = Modifier.padding(end = 4.dp))
        if (!atStop) VehicleMark(vehicleIcon, lineColor)
        repeat(shown) {
            Segment(lineColor)
            Box(Modifier.size(9.dp).border(2.dp, lineColor, CircleShape))
        }
        Segment(lineColor)
        if (atStop) VehicleMark(vehicleIcon, lineColor)
        else Box(Modifier.size(14.dp).background(lineColor, CircleShape).padding(3.dp).background(MaterialTheme.colorScheme.surfaceContainer, CircleShape))
    }
}

@Composable
private fun RowScope.Segment(color: Color) {
    Box(Modifier.weight(1f).height(3.dp).background(color.copy(alpha = 0.45f)))
}

@Composable
private fun VehicleMark(icon: ImageVector, color: Color) {
    Box(Modifier.size(22.dp).background(color, CircleShape), contentAlignment = Alignment.Center) {
        Icon(icon, null, tint = Color.White, modifier = Modifier.size(14.dp))
    }
}
