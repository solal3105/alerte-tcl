package com.alertetcl.android.ui.parking

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.theme.compose
import com.alertetcl.shared.design.AppColors
import com.alertetcl.shared.models.VelovStation

/** Fiche d'une station Vélo'v : vélos et places disponibles, dernière mise à jour, itinéraire à pied. */
@Composable
fun VelovStationSheet(station: VelovStation) {
    val context = LocalContext.current
    val color = AppColors.parkingAvailability(station.availability).compose()
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { kotlinx.coroutines.delay(30_000); nowMs = System.currentTimeMillis() } }
    Column(
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(modifier = Modifier.size(60.dp).clip(CircleShape).background(color.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.DirectionsBike, null, tint = color, modifier = Modifier.size(30.dp))
            }
            Text(station.displayName, fontWeight = FontWeight.Bold, fontSize = 19.sp, textAlign = TextAlign.Center)
            if (station.address.isNotEmpty()) {
                Text(station.address, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            VelovStat(value = station.bikes, caption = if (station.bikes > 1) "vélos disponibles" else "vélo disponible", color = color, modifier = Modifier.weight(1f))
            VelovStat(value = station.stands, caption = if (station.stands > 1) "places libres" else "place libre", color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
        }
        Surface(shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surfaceVariant, modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(station.bikesText, fontSize = 14.sp)
                if (station.standsText.isNotEmpty()) Text(station.standsText, fontSize = 14.sp)
                val updated = station.updatedText(nowMs)
                if (updated.isNotEmpty()) Text(updated, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Button(
            onClick = {
                val uri = android.net.Uri.parse("geo:${station.lat},${station.lng}?q=${station.lat},${station.lng}(Vélo'v ${android.net.Uri.encode(station.displayName)})")
                runCatching { context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, uri)) }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(Icons.Filled.DirectionsWalk, null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Itinéraire dans une app de cartes")
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun VelovStat(value: Int, caption: String, color: Color, modifier: Modifier) {
    Surface(shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surfaceVariant, modifier = modifier) {
        Column(modifier = Modifier.padding(vertical = 14.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("$value", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = color)
            Text(caption, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/**
 * Marqueur d'une station Vélo'v au zoom serré : carré arrondi à la couleur de disponibilité, vélo (ou
 * éclair pour les seuls vélos électriques) et nombre de vélos (parité iOS `VelovMarker`).
 */
fun velovMarkerBitmap(bikes: Int, colorHex: String, electric: Boolean): Bitmap {
    val density = android.content.res.Resources.getSystem().displayMetrics.density
    val size = (30 * density).toInt()
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val inset = 1.5f * density
    val rect = RectF(inset, inset, size - inset, size - inset)
    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.parseColor(colorHex); style = Paint.Style.FILL; setShadowLayer(2f * density, 0f, density, AndroidColor.argb(64, 0, 0, 0)) }
    canvas.drawRoundRect(rect, 9 * density, 9 * density, fill)
    val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.argb(230, 255, 255, 255); style = Paint.Style.STROKE; strokeWidth = 1.5f * density }
    canvas.drawRoundRect(rect, 9 * density, 9 * density, stroke)
    val cx = size / 2f
    if (electric) {
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
    val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; textSize = 10f * density; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.CENTER }
    canvas.drawText(bikes.toString(), cx, size - 4.5f * density, text)
    return bmp
}
