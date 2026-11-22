package com.alertetcl.android.ui.live

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import com.alertetcl.shared.design.AppColors
import com.alertetcl.shared.design.MapStyle
import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.NetworkCuts
import com.google.gson.JsonObject
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.maps.Style
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point

// Coupures du réseau sur la carte Transport : dessine ce que rend `NetworkCuts.mapCuts` (module
// partagé). Un fond efface la couleur de la ligne, puis des points gris (coupé) ou des tirets à sa
// couleur (plus tard aujourd'hui), une pastille par coupure, et la marque des arrêts touchés.
// Règles dans DESIGN.md (« Coupures du réseau »).

internal const val CUTS_CASING_LAYER = "cuts-casing-layer"
internal const val CUTS_PIN_LAYER = "cuts-pin-layer"
internal const val CUT_MARKS_LAYER = "cut-marks-layer"
private const val CUTS_SRC = "cuts-src"
private const val CUTS_PIN_SRC = "cuts-pin-src"
private const val CUT_MARKS_SRC = "cut-marks-src"
private const val CUTS_DOTS_LAYER = "cuts-dots-layer"
private const val CUTS_DASH_LAYER = "cuts-dash-layer"
private const val MARK_SOME_ICON = "cut_mark_some"
private const val MARK_ALL_ICON = "cut_mark_all"
/** Les bitmaps de la carte sont dessinés à cette échelle, comme ceux des arrêts et des véhicules. */
private const val DENSITY = 3f

/** Une coupure telle que la carte la pose : ses tracés (ceux du fichier, ou ceux de la ligne entière) et sa pastille. */
internal data class DrawnCut(val mapCut: NetworkCuts.MapCut, val traces: List<List<LatLng>>) {
    val anchor: LatLng? get() = mapCut.anchor ?: traces.maxByOrNull { it.size }?.let { NetworkCuts.midpoint(it) }
    val pinIcon: String get() = "cutpin_${mapCut.style}_${mapCut.line}_${mapCut.label}".replace(Regex("[^A-Za-z0-9_]"), "_")
}

/** Arrêt marqué : sa position et ce qu'il faut y poser. */
internal data class MarkedStop(val position: LatLng, val mark: NetworkCuts.StopMark)

/**
 * Pose ou met à jour les coupures. [below] : couches existantes sous lesquelles glisser les tracés
 * (les arrêts et les véhicules restent au-dessus). [surface]/[onSurface] : couleurs de la pastille.
 */
internal fun syncCutLayers(
    style: Style,
    cuts: List<DrawnCut>,
    marks: List<MarkedStop>,
    isDark: Boolean,
    surface: Int,
    onSurface: Int,
    below: Array<String>,
    marksBelow: Array<String>
) {
    val lines = FeatureCollection.fromFeatures(cuts.flatMap { drawn ->
        drawn.traces.filter { it.size >= 2 }.map { trace ->
            Feature.fromGeometry(
                LineString.fromLngLats(trace.map { Point.fromLngLat(it.longitude, it.latitude) }),
                JsonObject().apply {
                    addProperty("style", drawn.mapCut.style.name)
                    addProperty("color", LineColors.routeStrokeHex(drawn.mapCut.line))
                }
            )
        }
    })
    val pins = cuts.mapNotNull { drawn ->
        val anchor = drawn.anchor ?: return@mapNotNull null
        if (style.getImage(drawn.pinIcon) == null) style.addImage(drawn.pinIcon, cutPastilleBitmap(drawn.mapCut, surface, onSurface))
        Feature.fromGeometry(Point.fromLngLat(anchor.longitude, anchor.latitude), JsonObject().apply {
            addProperty("icon", drawn.pinIcon)
            addProperty("line", drawn.mapCut.line)
        })
    }
    if (style.getImage(MARK_SOME_ICON) == null) style.addImage(MARK_SOME_ICON, stopMarkBitmap(allLines = false))
    if (style.getImage(MARK_ALL_ICON) == null) style.addImage(MARK_ALL_ICON, stopMarkBitmap(allLines = true))
    val markFeatures = marks.map { m ->
        Feature.fromGeometry(Point.fromLngLat(m.position.longitude, m.position.latitude), JsonObject().apply {
            addProperty("icon", if (m.mark == NetworkCuts.StopMark.ALL_LINES) MARK_ALL_ICON else MARK_SOME_ICON)
        })
    }

    val linesSource = style.getSourceAs<GeoJsonSource>(CUTS_SRC)
    if (linesSource != null) {
        linesSource.setGeoJson(lines)
        style.getSourceAs<GeoJsonSource>(CUTS_PIN_SRC)?.setGeoJson(FeatureCollection.fromFeatures(pins))
        style.getSourceAs<GeoJsonSource>(CUT_MARKS_SRC)?.setGeoJson(FeatureCollection.fromFeatures(markFeatures))
        return
    }
    style.addSource(GeoJsonSource(CUTS_SRC, lines))
    style.addSource(GeoJsonSource(CUTS_PIN_SRC, FeatureCollection.fromFeatures(pins)))
    style.addSource(GeoJsonSource(CUT_MARKS_SRC, FeatureCollection.fromFeatures(markFeatures)))

    val casing = LineLayer(CUTS_CASING_LAYER, CUTS_SRC).withProperties(
        PropertyFactory.lineColor(AppColors.cutCasing.hex(isDark)),
        PropertyFactory.lineWidth(MapStyle.CUT_CASING_WIDTH.toFloat()),
        PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
        PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)
    )
    val dots = LineLayer(CUTS_DOTS_LAYER, CUTS_SRC).withProperties(
        PropertyFactory.lineColor(AppColors.cutTrace.hex(isDark)),
        PropertyFactory.lineWidth(MapStyle.CUT_DOT_WIDTH.toFloat()),
        PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
        PropertyFactory.lineDasharray(dashArray(MapStyle.CUT_DOT_PATTERN, MapStyle.CUT_DOT_WIDTH))
    ).withFilter(Expression.eq(Expression.get("style"), Expression.literal(NetworkCuts.MapStyleKind.CUT.name)))
    val dashes = LineLayer(CUTS_DASH_LAYER, CUTS_SRC).withProperties(
        PropertyFactory.lineColor(Expression.get("color")),
        PropertyFactory.lineWidth(MapStyle.SOON_DASH_WIDTH.toFloat()),
        PropertyFactory.lineCap(Property.LINE_CAP_BUTT),
        PropertyFactory.lineDasharray(dashArray(MapStyle.SOON_DASH_PATTERN, MapStyle.SOON_DASH_WIDTH))
    ).withFilter(Expression.eq(Expression.get("style"), Expression.literal(NetworkCuts.MapStyleKind.SOON.name)))
    val anchorBelow = below.firstOrNull { style.getLayer(it) != null }
    listOf(casing, dots, dashes).forEach { if (anchorBelow != null) style.addLayerBelow(it, anchorBelow) else style.addLayer(it) }

    val marksLayer = SymbolLayer(CUT_MARKS_LAYER, CUT_MARKS_SRC).withProperties(
        PropertyFactory.iconImage(Expression.get("icon")),
        PropertyFactory.iconAllowOverlap(true),
        PropertyFactory.iconIgnorePlacement(true)
    )
    marksLayer.setMinZoom(MapStyle.ZOOM_STOPS.toFloat())
    val marksAnchor = marksBelow.firstOrNull { style.getLayer(it) != null }
    if (marksAnchor != null) style.addLayerBelow(marksLayer, marksAnchor) else style.addLayer(marksLayer)
    // Les pastilles par-dessus tout : on les touche pour ouvrir la fiche de la ligne.
    style.addLayer(SymbolLayer(CUTS_PIN_LAYER, CUTS_PIN_SRC).withProperties(
        PropertyFactory.iconImage(Expression.get("icon")),
        PropertyFactory.iconAllowOverlap(true),
        PropertyFactory.iconIgnorePlacement(true)
    ))
}

/** Motif en points d'écran ramené à l'épaisseur du trait, l'unité de MapLibre. */
private fun dashArray(pattern: List<Double>, width: Double): Array<Float> = pattern.map { (it / width).toFloat() }.toTypedArray()

/**
 * Pastille : badge de la ligne et sens interdit (coupé) ou horloge (plus tard aujourd'hui), l'étiquette
 * dessous. Le centre du badge tombe au centre de l'image, posée centrée sur le tracé.
 */
private fun cutPastilleBitmap(mapCut: NetworkCuts.MapCut, surface: Int, onSurface: Int): Bitmap {
    val d = DENSITY
    val badgeText = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 12 * d; typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER }
    val labelText = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11 * d; typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER; color = onSurface }
    val pad = 4 * d
    val badgeH = 22 * d
    val badgeW = badgeText.measureText(mapCut.line) + 14 * d
    val icon = 20 * d
    val rowW = pad + badgeW + 4 * d + icon + pad
    val rowH = badgeH + 2 * pad
    val labelW = labelText.measureText(mapCut.label) + 14 * d
    val labelH = 18 * d
    val gap = 3 * d
    val width = maxOf(rowW, labelW) + 2 * d
    // Marge du haut égale à ce qu'il y a sous la rangée, pour que son centre soit celui de l'image.
    val height = 2 * (rowH / 2 + gap + labelH) + 2 * d
    val bmp = Bitmap.createBitmap(width.toInt(), height.toInt(), Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    val cx = width / 2
    val rowTop = height / 2 - rowH / 2

    fill.color = surface
    fill.setShadowLayer(3 * d, 0f, d, AndroidColor.argb(50, 0, 0, 0))
    canvas.drawRoundRect(RectF(cx - rowW / 2, rowTop, cx + rowW / 2, rowTop + rowH), rowH / 2, rowH / 2, fill)
    val labelTop = rowTop + rowH + gap
    canvas.drawRoundRect(RectF(cx - labelW / 2, labelTop, cx + labelW / 2, labelTop + labelH), labelH / 2, labelH / 2, fill)
    fill.clearShadowLayer()

    val badgeLeft = cx - rowW / 2 + pad
    fill.color = AndroidColor.parseColor(LineColors.backgroundHex(mapCut.line))
    canvas.drawRoundRect(RectF(badgeLeft, rowTop + pad, badgeLeft + badgeW, rowTop + pad + badgeH), badgeH / 2, badgeH / 2, fill)
    badgeText.color = AndroidColor.parseColor(LineColors.textHex(mapCut.line))
    canvas.drawText(mapCut.line, badgeLeft + badgeW / 2, rowTop + pad + badgeH / 2 + badgeText.textSize * 0.36f, badgeText)

    val iconCx = badgeLeft + badgeW + 4 * d + icon / 2
    val iconCy = rowTop + rowH / 2
    val soon = mapCut.style == NetworkCuts.MapStyleKind.SOON
    fill.color = AndroidColor.parseColor(if (soon) AppColors.warning.light else AppColors.error.light)
    canvas.drawCircle(iconCx, iconCy, icon / 2, fill)
    val white = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; strokeWidth = 2.2f * d; strokeCap = Paint.Cap.ROUND; style = Paint.Style.STROKE }
    if (soon) {
        canvas.drawLine(iconCx, iconCy, iconCx, iconCy - icon * 0.28f, white)
        canvas.drawLine(iconCx, iconCy, iconCx + icon * 0.22f, iconCy, white)
    } else {
        canvas.drawLine(iconCx - icon * 0.27f, iconCy, iconCx + icon * 0.27f, iconCy, white)
    }

    canvas.drawText(mapCut.label, cx, labelTop + labelH / 2 + labelText.textSize * 0.36f, labelText)
    return bmp
}

/**
 * Marque d'un arrêt, centrée sur lui : cercle gris barré quand plus aucune ligne ne passe ([allLines]),
 * sinon petit sens interdit rouge en haut à droite du disque.
 */
private fun stopMarkBitmap(allLines: Boolean): Bitmap {
    val d = DENSITY
    val side = (24 * d).toInt()
    val bmp = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)
    val c = side / 2f
    if (allLines) {
        val grey = AndroidColor.parseColor(AppColors.cutTrace.light)
        val r = 8 * d
        canvas.drawCircle(c, c, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE })
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = grey; style = Paint.Style.STROKE; strokeWidth = 1.6f * d; strokeCap = Paint.Cap.ROUND }
        canvas.drawCircle(c, c, r, stroke)
        val k = r * 0.45f
        canvas.drawLine(c - k, c - k, c + k, c + k, stroke)
        canvas.drawLine(c + k, c - k, c - k, c + k, stroke)
    } else {
        val r = 5 * d
        val x = c + 6 * d; val y = c - 6 * d
        canvas.drawCircle(x, y, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.parseColor(AppColors.error.light) })
        canvas.drawCircle(x, y, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE; style = Paint.Style.STROKE; strokeWidth = d })
        canvas.drawRect(x - r * 0.55f, y - d, x + r * 0.55f, y + d, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE })
    }
    return bmp
}
