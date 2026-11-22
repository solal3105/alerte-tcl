package com.alertetcl.android.ui.cuts

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EventRepeat
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.android.ui.components.LineBadge
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.NetworkCut
import com.alertetcl.shared.models.NetworkCuts

// Coupures du réseau : briques des fiches et de la feuille Trafic. Tout ce qui est écrit ou décidé
// vient de [NetworkCuts] (module partagé) ; ces vues ne font que dessiner. Règles dans DESIGN.md
// (« Coupures du réseau »). La carte est dans `ui/live/NetworkCutsMapLayer.kt`.

/** Phrase d'une carte de passages quand la ligne ne passe pas ici, maintenant ou ce soir. */
@Composable
internal fun CutNoticeRow(stopCut: NetworkCuts.StopCut, nowEpoch: Long) {
    val now = stopCut.timing.phase == NetworkCuts.Phase.NOW
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(
            if (now) Icons.Filled.RemoveCircle else Icons.Filled.Schedule, null,
            tint = if (now) Tokens.error else Tokens.warning, modifier = Modifier.size(18.dp).padding(top = 1.dp)
        )
        Text(NetworkCuts.stopNotice(stopCut, nowEpoch), fontSize = 14.sp)
    }
}

// ── Fiche de ligne ───────────────────────────────────────────────────────

/** Bloc en haut de la fiche d'une ligne : ce qui ne circule pas, quand, et où sur un petit schéma. */
@Composable
internal fun CutLineBlock(block: NetworkCuts.LineBlock, onShowOnMap: (() -> Unit)?) {
    val isNow = block.phase == NetworkCuts.Phase.NOW
    Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainer, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(
                    if (isNow) Icons.Filled.RemoveCircle else Icons.Filled.EventRepeat, null,
                    tint = if (isNow) Tokens.error else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(22.dp)
                )
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(block.headline, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    block.detail?.let { Text(it, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    block.note?.let { note ->
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Icon(Icons.Filled.Warning, null, tint = Tokens.warning, modifier = Modifier.size(14.dp).padding(top = 2.dp))
                            Text(note, fontSize = 13.sp, color = Tokens.warning)
                        }
                    }
                }
            }
            if (block.diagram.isNotEmpty()) CutDiagram(block.diagram, block.cut.ligne, isNow)
            if (onShowOnMap != null) {
                FilledTonalButton(onClick = onShowOnMap, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                    Icon(Icons.Filled.Map, null, modifier = Modifier.size(18.dp))
                    Text("Voir sur la carte", fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 8.dp))
                }
            }
        }
    }
}

/**
 * Schéma de la ligne : arrêts desservis en anneaux à la couleur de la ligne, tronçon coupé en
 * pointillé gris et arrêts barrés quand c'est maintenant, en tirets à sa couleur quand c'est à venir.
 */
@Composable
private fun CutDiagram(stops: List<NetworkCuts.DiagramStop>, line: String, isNow: Boolean) {
    val lineColor = colorFromHex(LineColors.backgroundHex(line))
    val cutColor = Tokens.cutTrace
    val ring = MaterialTheme.colorScheme.surfaceContainer
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val density = LocalDensity.current
    BoxWithConstraints(modifier = Modifier.fillMaxWidth().height(64.dp)) {
        val width = constraints.maxWidth.toFloat()
        val inset = with(density) { 12.dp.toPx() }
        val step = if (stops.size > 1) (width - 2 * inset) / (stops.size - 1) else 0f
        val xs = stops.indices.map { if (stops.size > 1) inset + it * step else width / 2 }
        val rowY = with(density) { 10.dp.toPx() }
        Canvas(modifier = Modifier.fillMaxWidth().height(24.dp)) {
            val gap = 18.dp.toPx()
            stops.dropLast(1).forEachIndexed { i, stop ->
                val a = xs[i]; val b = xs[i + 1]; val mid = (a + b) / 2
                val color = if (stop.cutAfter && isNow) cutColor else lineColor
                val (strokeWidth, effect, cap) = when {
                    !stop.cutAfter -> Triple(4.dp.toPx(), null, StrokeCap.Round)
                    isNow -> Triple(3.dp.toPx(), PathEffect.dashPathEffect(floatArrayOf(0.1f, 7.dp.toPx())), StrokeCap.Round)
                    else -> Triple(4.dp.toPx(), PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx())), StrokeCap.Butt)
                }
                val half = if (stop.gapAfter) gap / 2 else 0f
                drawLine(color, Offset(a, rowY), Offset(mid - half, rowY), strokeWidth, cap, effect)
                drawLine(color, Offset(mid + half, rowY), Offset(b, rowY), strokeWidth, cap, effect)
            }
            stops.forEachIndexed { i, stop ->
                val center = Offset(xs[i], rowY)
                if (stop.cut && isNow) {
                    val r = 7.dp.toPx()
                    drawCircle(ring, r, center)
                    drawCircle(cutColor, r, center, style = Stroke(1.6.dp.toPx()))
                    val d = r * 0.45f
                    drawLine(cutColor, center + Offset(-d, -d), center + Offset(d, d), 1.6.dp.toPx(), StrokeCap.Round)
                    drawLine(cutColor, center + Offset(d, -d), center + Offset(-d, d), 1.6.dp.toPx(), StrokeCap.Round)
                } else {
                    val r = (if (stop.bound) 9.dp else 6.5.dp).toPx()
                    drawCircle(ring, r, center)
                    drawCircle(lineColor, r - 1.5.dp.toPx(), center, style = Stroke(3.dp.toPx()))
                }
            }
        }
        val labelWidth = width / stops.size
        stops.forEachIndexed { i, stop ->
            if (stop.gapAfter && i < stops.lastIndex) {
                val mid = (xs[i] + xs[i + 1]) / 2
                Text("…", fontSize = 12.sp, color = muted, modifier = Modifier.offset(x = with(density) { mid.toDp() - 4.dp }, y = (-2).dp))
            }
            val x = (xs[i] - labelWidth / 2).coerceIn(0f, width - labelWidth)
            Text(
                stop.name, fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                fontWeight = if (stop.bound) FontWeight.SemiBold else FontWeight.Normal,
                color = if (stop.cut && isNow) muted else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.width(with(density) { labelWidth.toDp() }).offset(x = with(density) { x.toDp() }, y = 24.dp)
            )
        }
    }
}

// ── Feuille Trafic ───────────────────────────────────────────────────────

/** « Coupures annoncées » : ce que TCL a publié pour plus tard, par jours. Touchez une ligne pour sa fiche. */
@Composable
internal fun UpcomingCutsSection(groups: List<NetworkCuts.UpcomingGroup>, onSelect: (NetworkCut) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Coupures annoncées", fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(
                "Ce que TCL a déjà publié pour les prochains jours. Ce qui est coupé en ce moment est sur la carte.",
                fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        groups.forEach { group ->
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(group.title.uppercase(), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainer, modifier = Modifier.fillMaxWidth()) {
                    Column {
                        group.rows.forEachIndexed { index, row ->
                            Row(
                                modifier = Modifier.fillMaxWidth().clickable { onSelect(row.cut) }.padding(horizontal = 16.dp, vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                LineBadge(row.cut.ligne, size = 34.dp)
                                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(row.title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                                    Text(row.subtitle, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Icon(Icons.Filled.ChevronRight, null, tint = MaterialTheme.colorScheme.outline)
                            }
                            if (index < group.rows.lastIndex) HorizontalDivider(modifier = Modifier.padding(start = 16.dp))
                        }
                    }
                }
            }
        }
    }
}

// ── Carte ────────────────────────────────────────────────────────────────

/** Bandeau de l'aperçu d'une coupure annoncée : quand elle aura lieu, et le retour à la carte en direct. */
@Composable
internal fun CutPreviewBanner(cut: NetworkCut, title: String, onClose: () -> Unit) {
    Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surfaceContainerHigh, shadowElevation = 4.dp, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(start = 12.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            LineBadge(cut.ligne, size = 28.dp, fontSize = 11.sp)
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text("Coupure annoncée par TCL, sans les véhicules", style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            TextButton(onClick = onClose) { Text("Revenir au direct", fontSize = 12.sp) }
        }
    }
}
