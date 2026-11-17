package com.alertetcl.android.ui.parking

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.ElectricBike
import androidx.compose.material.icons.filled.LocalParking
import androidx.compose.material.icons.filled.PedalBike
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.components.SheetHeader
import com.alertetcl.android.ui.components.glass
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.VelovFilter
import com.alertetcl.shared.models.VelovStation
import com.alertetcl.shared.models.VelovTexts
import com.alertetcl.shared.viewmodels.VelovStationSelection

/**
 * Choix de ce que chaque station Vélo'v compte : tous ses vélos, ses vélos classiques, ses vélos
 * électriques ou ses places libres. Le même choix, gardé d'une ouverture à l'autre, sert à la carte et à
 * la fiche d'une station : en haut de la carte ([onMap]), la barre est en verre et porte les
 * pictogrammes ; dans la fiche, déjà posée sur une surface, elle est pleine et réduite aux titres.
 */
@Composable
fun VelovFilterBar(selected: VelovFilter, onSelect: (VelovFilter) -> Unit, modifier: Modifier = Modifier, onMap: Boolean = true) {
    val container = if (onMap) Modifier.glass(RoundedCornerShape(26.dp))
    else Modifier
        .clip(RoundedCornerShape(16.dp))
        .background(MaterialTheme.colorScheme.surface)
        .semantics { contentDescription = VelovTexts.FILTER_LABEL }
    Row(
        modifier = modifier.then(container).padding(4.dp).selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        VelovFilter.ordered.forEach { filter ->
            val active = filter == selected
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(if (onMap) 22.dp else 12.dp))
                    .background(if (active) Tokens.accent else Color.Transparent)
                    .selectable(selected = active, role = Role.RadioButton, onClick = { onSelect(filter) })
                    .padding(vertical = if (onMap) 7.dp else 9.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                val tint = if (active) Color.White else MaterialTheme.colorScheme.onSurface
                if (onMap) Icon(velovFilterIcon(filter), filter.caption, tint = tint, modifier = Modifier.size(20.dp))
                Text(
                    filter.title,
                    style = if (onMap) MaterialTheme.typography.labelSmall else MaterialTheme.typography.labelMedium,
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                    color = tint,
                    maxLines = 1
                )
            }
        }
    }
}

private fun velovFilterIcon(filter: VelovFilter): ImageVector = when (filter) {
    VelovFilter.ALL -> Icons.Filled.DirectionsBike
    VelovFilter.MECHANICAL -> Icons.Filled.PedalBike
    VelovFilter.ELECTRIC -> Icons.Filled.ElectricBike
    VelovFilter.STANDS -> Icons.Filled.LocalParking
}

/**
 * Fiche d'une station Vélo'v : son nom, une tuile de son état réel ([VelovNowTile]), une tuile de ce qui
 * y est prévu dans les 24 heures ([VelovForecastSection] : graphique et curseur, dès l'ouverture),
 * l'itinéraire à pied. Sans prévision à montrer (modèle absent ou plus confirmé, station fermée ou
 * inconnue du modèle), il ne reste que l'état réel et l'itinéraire, sans mention de la prévision.
 *
 * Le filtre est celui de la carte : le changer ici le change aussi sur la carte. [initialStep] est
 * l'échéance du curseur de la carte à l'ouverture ; elle n'appartient ensuite qu'à la fiche. Toucher une
 * station voisine ([onOpenNeighbour]) la montre à la même échéance, avec une flèche pour revenir ([onBack]).
 */
@Composable
fun VelovStationSheet(
    selection: VelovStationSelection,
    filter: VelovFilter,
    onFilter: (VelovFilter) -> Unit,
    initialStep: Int,
    onOpenNeighbour: (VelovStation) -> Unit,
    onBack: () -> Unit,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val station = selection.station
    val showsForecast = selection.forecast != null || selection.forecastPending
    // Avec une prévision, la hauteur est fixe : la feuille tient par le bas, et sans cela le graphique
    // remonterait sous le doigt chaque fois que « Plus sûr à côté » apparaît pendant que le curseur glisse.
    val height = if (showsForecast) Modifier.fillMaxHeight(0.92f) else Modifier
    Column(modifier = height.verticalScroll(rememberScrollState())) {
        SheetHeader(
            title = station.displayName,
            onClose = onClose,
            leading = if (selection.hasPrevious) {
                {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Revenir à la station précédente")
                    }
                }
            } else null
        )
        Column(
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            VelovNowTile(station)
            if (showsForecast) VelovForecastSection(selection.forecast, filter, onFilter, initialStep, onOpenNeighbour)
            Button(
                onClick = {
                    val uri = android.net.Uri.parse("geo:${station.lat},${station.lng}?q=${station.lat},${station.lng}(Vélo'v ${android.net.Uri.encode(station.displayName)})")
                    runCatching { context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, uri)) }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Filled.DirectionsWalk, null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("Itinéraire à pied")
            }
        }
    }
}

/**
 * L'état réel de la station, en tête de fiche : vélos classiques, vélos électriques et places libres côte
 * à côte, chacun avec le pictogramme de son filtre, son nombre et son mot ; « Station fermée » si elle
 * l'est.
 */
@Composable
private fun VelovNowTile(station: VelovStation) {
    VelovCard {
        if (!station.open) {
            Text(
                station.stateText,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        } else {
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                VelovFilter.detailed.forEach { filter ->
                    val count = station.shownCount(filter)
                    Column(
                        modifier = Modifier.weight(1f).semantics(mergeDescendants = true) { },
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(velovFilterIcon(filter), null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
                        Text(count.toString(), fontSize = 26.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                        Text(
                            VelovTexts.unit(filter, count),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1
                        )
                    }
                }
            }
        }
    }
}

/**
 * Marqueur d'une station Vélo'v au zoom serré : carré arrondi à la couleur de disponibilité, le
 * pictogramme du filtre courant et [label], le nombre compté ou la fourchette prévue (parité iOS
 * `VelovMarker`). Le carré s'élargit pour une fourchette (« 12–25 ») en gardant autour du texte la
 * marge d'un nombre.
 */
fun velovMarkerBitmap(label: String, colorHex: String, filter: VelovFilter): Bitmap {
    val density = android.content.res.Resources.getSystem().displayMetrics.density
    val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; textSize = 10f * density; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.CENTER }
    val height = (30 * density).toInt()
    val width = maxOf(height, (text.measureText(label) + 10 * density).toInt())
    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val inset = 1.5f * density
    val rect = RectF(inset, inset, width - inset, height - inset)
    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.parseColor(colorHex); style = Paint.Style.FILL; setShadowLayer(2f * density, 0f, density, AndroidColor.argb(64, 0, 0, 0)) }
    canvas.drawRoundRect(rect, 9 * density, 9 * density, fill)
    val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.argb(230, 255, 255, 255); style = Paint.Style.STROKE; strokeWidth = 1.5f * density }
    canvas.drawRoundRect(rect, 9 * density, 9 * density, stroke)
    val cx = width / 2f
    if (filter == VelovFilter.STANDS) {
        // Un « P » de place libre, comme le pictogramme des parkings.
        val letter = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = AndroidColor.WHITE; textSize = 13f * density
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.CENTER
        }
        canvas.drawText("P", cx, 14.5f * density, letter)
    } else if (filter == VelovFilter.ELECTRIC) {
        // Éclair plein.
        val bolt = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; style = Paint.Style.FILL }
        val path = android.graphics.Path().apply {
            moveTo(cx + 1.5f * density, 4.5f * density)
            lineTo(cx - 3.5f * density, 11f * density)
            lineTo(cx - 0.5f * density, 11f * density)
            lineTo(cx - 1.5f * density, 16.5f * density)
            lineTo(cx + 3.5f * density, 9.5f * density)
            lineTo(cx + 0.5f * density, 9.5f * density)
            close()
        }
        canvas.drawPath(path, bolt)
    } else {
        // Vélo stylisé : deux roues et un cadre.
        val glyph = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = 1.4f * density; strokeCap = Paint.Cap.ROUND }
        val wheelY = 12.5f * density
        val wheelR = 3.2f * density
        canvas.drawCircle(cx - 5.5f * density, wheelY, wheelR, glyph)
        canvas.drawCircle(cx + 5.5f * density, wheelY, wheelR, glyph)
        canvas.drawLine(cx - 5.5f * density, wheelY, cx - 1f * density, 7f * density, glyph)
        canvas.drawLine(cx - 1f * density, 7f * density, cx + 5.5f * density, wheelY, glyph)
        canvas.drawLine(cx - 1f * density, 7f * density, cx + 2.5f * density, 6f * density, glyph)
        canvas.drawLine(cx - 5.5f * density, wheelY, cx + 1.5f * density, wheelY, glyph)
    }
    canvas.drawText(label, cx, height - 4.5f * density, text)
    return bmp
}
