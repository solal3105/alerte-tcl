package com.alertetcl.shared.models

import com.alertetcl.shared.design.MapStyle
import com.alertetcl.shared.geo.LatLng
import com.alertetcl.shared.geo.fastDistance2D
import com.alertetcl.shared.util.parseIsoEpoch
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.isoDayNumber
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime

/**
 * Ce que l'application montre des coupures du réseau ([NetworkCutsFile]), le même sur iOS et Android :
 * l'état de chaque coupure à un instant, le dessin de la carte, les arrêts touchés, le bloc de la fiche
 * de ligne et la liste « Coupures annoncées » de la feuille Trafic. Règles dans DESIGN.md (« Coupures
 * du réseau »). Les vues ne recalculent rien : elles dessinent ce que ces fonctions rendent.
 */
object NetworkCuts {
    const val TIME_ZONE = "Europe/Paris"

    /** Au-delà, la lecture des alertes ne tourne plus : mieux vaut ne rien montrer qu'une coupure peut-être levée. */
    const val MAX_AGE_SECONDS = 6 * 3600L

    /** Un arrêt de la coupure et un arrêt de la carte sont le même lieu : même nom à cette distance, ou tout près. */
    private const val SAME_NAME_METERS = 400.0
    private const val SAME_PLACE_METERS = 60.0

    /** Une heure de fin avant 4 h du matin est la fin du service de la veille. */
    private const val SERVICE_END_HOUR = 4
    /** Une fenêtre qui commence avant 6 h commence avec le service : « toute la journée ». */
    private const val SERVICE_START_LATEST_HOUR = 6

    fun isFresh(file: NetworkCutsFile, nowEpoch: Long): Boolean =
        parseIsoEpoch(file.genere)?.let { nowEpoch - it <= MAX_AGE_SECONDS } ?: false

    /** Toutes les coupures du fichier, placées ou non, hors lignes scolaires. */
    fun all(file: NetworkCutsFile): List<NetworkCut> =
        (file.coupures + file.nonPlacees).filter { TransitStop.isDisplayedLine(it.ligne) }

    // ── État à un instant ────────────────────────────────────────────────────

    enum class Phase {
        /** Coupé en ce moment. */
        NOW,
        /** Coupé plus tard dans la journée (à partir de minuit le jour même). */
        LATER_TODAY,
        /** Coupé un autre jour. */
        UPCOMING
    }

    /** État d'une coupure : [window] est la fenêtre en cours ([Phase.NOW]) ou la prochaine. */
    data class Timing(val phase: Phase, val window: CutWindow)

    fun timing(cut: NetworkCut, nowEpoch: Long): Timing? {
        val remaining = cut.epochWindows.filter { it.end == null || it.end > nowEpoch }
        remaining.firstOrNull { it.contains(nowEpoch) }?.let { return Timing(Phase.NOW, it) }
        val next = remaining.firstOrNull { it.start > nowEpoch } ?: return null
        val sameDay = local(next.start).date == local(nowEpoch).date
        return Timing(if (sameDay) Phase.LATER_TODAY else Phase.UPCOMING, next)
    }

    /** Fenêtres encore à venir ou en cours. */
    fun remainingWindows(cut: NetworkCut, nowEpoch: Long): List<CutWindow> =
        cut.epochWindows.filter { it.end == null || it.end > nowEpoch }

    // ── Carte ────────────────────────────────────────────────────────────────

    enum class MapStyleKind {
        /** Coupé : pointillé gris, la ligne perd sa couleur. */
        CUT,
        /** Bientôt coupé, ou coupé à des heures que TCL ne précise pas : tirets à la couleur de la ligne. */
        SOON
    }

    /** Une coupure telle que la carte la dessine. [anchor] : la pastille, null tant que la plateforme ne l'a pas placée sur le tracé de la ligne. */
    data class MapCut(
        val cut: NetworkCut,
        val style: MapStyleKind,
        val traces: List<List<LatLng>>,
        val anchor: LatLng?,
        /** Texte sous la pastille : « Jusqu'à 13 h », « Dès 21 h 20 ». */
        val label: String,
        /** Métro, tram et trambus se voient de loin ; un bus seulement de près, ou si on le demande. */
        val isRail: Boolean
    ) {
        val line: String get() = cut.ligne
        val colorHex: String get() = cut.couleur
    }

    /**
     * Ce que la carte dessine maintenant : les coupures en cours et celles de plus tard dans la journée.
     * Les arrêts seuls fermés n'ont pas de pastille : leur arrêt porte la marque ([stopMark]).
     */
    fun mapCuts(file: NetworkCutsFile?, nowEpoch: Long): List<MapCut> {
        if (file == null || !isFresh(file, nowEpoch)) return emptyList()
        return all(file).mapNotNull { cut ->
            val timing = timing(cut, nowEpoch)?.takeIf { it.phase != Phase.UPCOMING } ?: return@mapNotNull null
            mapCut(cut, timing, nowEpoch)
        }
    }

    /** Aperçu d'une coupure annoncée, pour la carte « comme elle sera » : toujours dessinée coupée. */
    fun previewCut(cut: NetworkCut, nowEpoch: Long): MapCut? {
        val window = remainingWindows(cut, nowEpoch).firstOrNull() ?: return null
        return mapCut(cut, Timing(Phase.NOW, window), nowEpoch)?.copy(style = MapStyleKind.CUT)
    }

    private fun mapCut(cut: NetworkCut, timing: Timing, nowEpoch: Long): MapCut? {
        if (cut.traces.isEmpty() && !cut.wholeLine) return null
        val traces = cut.traces.map { it.points }.filter { it.size >= 2 }
        val partial = cut.partialTimes && timing.phase == Phase.NOW
        val style = if (timing.phase == Phase.NOW && !partial) MapStyleKind.CUT else MapStyleKind.SOON
        val label = when {
            partial -> "À certaines heures"
            timing.phase == Phase.NOW -> capitalize(untilText(timing.window.end, nowEpoch))
            else -> "Dès ${hour(timing.window.start)}"
        }
        return MapCut(cut, style, traces, traces.maxByOrNull { length(it) }?.let { midpoint(it) }, label, cut.mode != "bus")
    }

    /** Une coupure se voit à ce zoom ? Les bus de loin seulement si leurs tracés sont affichés ou leur ligne choisie dans les filtres. */
    fun isShown(cut: MapCut, zoom: Double, busTracesShown: Boolean, filteredLines: Set<String>): Boolean =
        cut.isRail || zoom >= MapStyle.ZOOM_STOPS || busTracesShown || filteredLines.any { it.equals(cut.line, ignoreCase = true) }

    /** Point au milieu d'un tracé, en longueur : la place de la pastille. */
    fun midpoint(points: List<LatLng>): LatLng? {
        if (points.isEmpty()) return null
        val half = length(points) / 2
        var walked = 0.0
        for (i in 1 until points.size) {
            val step = fastDistance2D(points[i - 1], points[i])
            if (walked + step >= half && step > 0) {
                val f = (half - walked) / step
                val a = points[i - 1]; val b = points[i]
                return LatLng(a.latitude + (b.latitude - a.latitude) * f, a.longitude + (b.longitude - a.longitude) * f)
            }
            walked += step
        }
        return points.last()
    }

    private fun length(points: List<LatLng>): Double =
        (1 until points.size).sumOf { fastDistance2D(points[it - 1], points[it]) }

    // ── Arrêts ───────────────────────────────────────────────────────────────

    /** Une ligne coupée à un arrêt. [direction] : « A » ou « R » quand un seul sens est touché, null pour les deux. */
    data class StopCut(val cut: NetworkCut, val line: String, val direction: String?, val timing: Timing) {
        fun appliesTo(directionCode: String?): Boolean = direction == null || directionCode == null || direction == directionCode
    }

    /**
     * Coupures, en cours ou plus tard aujourd'hui, des lignes [lines] à l'arrêt [name] situé en [position].
     * Une ligne entière coupée l'est à tous ses arrêts, même quand TCL ne les cite pas.
     */
    fun stopCuts(file: NetworkCutsFile?, name: String, position: LatLng, lines: List<String>, nowEpoch: Long): List<StopCut> {
        if (file == null || !isFresh(file, nowEpoch)) return emptyList()
        val normalized = DirectionMatching.normalize(name)
        return all(file).mapNotNull { cut ->
            val line = lines.firstOrNull { it.equals(cut.ligne, ignoreCase = true) } ?: return@mapNotNull null
            val timing = timing(cut, nowEpoch)?.takeIf { it.phase != Phase.UPCOMING } ?: return@mapNotNull null
            if (cut.wholeLine) return@mapNotNull StopCut(cut, line, null, timing)
            val here = cut.stops.filter { stop ->
                val distance = fastDistance2D(stop.coordinate, position)
                distance <= SAME_PLACE_METERS || (distance <= SAME_NAME_METERS && DirectionMatching.normalize(stop.name) == normalized)
            }
            if (here.isEmpty()) return@mapNotNull null
            // Un arrêt n'est publié qu'une fois par lieu : le sens ne se lit que sur la coupure entière.
            StopCut(cut, line, cut.directions.singleOrNull(), timing)
        }
    }

    enum class StopMark { NONE, SOME_LINES, ALL_LINES }

    /** Marque d'un arrêt sur la carte : badge rouge si une de ses lignes ne passe plus, gris barré si plus aucune. */
    fun stopMark(cuts: List<StopCut>, lines: List<String>): StopMark {
        val now = cuts.filter { it.timing.phase == Phase.NOW && !it.cut.partialTimes }
        if (now.isEmpty()) return StopMark.NONE
        val fullyCut = now.filter { it.direction == null }.map { it.line.uppercase() }.toSet()
        return if (lines.isNotEmpty() && lines.all { it.uppercase() in fullyCut }) StopMark.ALL_LINES else StopMark.SOME_LINES
    }

    /** Fenêtres où la ligne [line] ne passe pas à l'arrêt dans le sens [directionCode] : les horaires prévus y sont retirés. */
    fun windowsAt(cuts: List<StopCut>, line: String, directionCode: String?): List<CutWindow> =
        cuts.filter { it.line.equals(line, ignoreCase = true) && it.appliesTo(directionCode) && !it.cut.partialTimes }
            .map { it.timing.window }

    /** Phrase de la fiche d'arrêt pour une ligne coupée ici, dans le sens d'une carte de passages. */
    fun stopNotice(stopCut: StopCut, nowEpoch: Long): String {
        val subject = subject(stopCut.cut)
        val towards = stopCut.direction?.let { stopCut.cut.destinations[it] }?.let { " vers $it" }.orEmpty()
        val window = stopCut.timing.window
        return when {
            stopCut.cut.partialTimes -> "$subject ne passe pas ici$towards à certaines heures, ${untilText(window.end, nowEpoch)}. Les horaires prévus peuvent être faux."
            stopCut.timing.phase == Phase.NOW -> "$subject ne passe pas ici$towards, ${untilText(window.end, nowEpoch)}."
            else -> "$subject est coupé ici$towards ${dayPart(window.start)} dès ${hour(window.start)}. Les horaires s'arrêtent au dernier passage avant la coupure."
        }
    }

    // ── Fiche de ligne ───────────────────────────────────────────────────────

    /** Un arrêt du schéma de la ligne : [cut] barré, [gapAfter] des arrêts omis jusqu'au suivant. */
    data class DiagramStop(val name: String, val cut: Boolean, val bound: Boolean, val gapAfter: Boolean, val cutAfter: Boolean)

    data class LineBlock(
        val cut: NetworkCut,
        val phase: Phase,
        /** Phrase principale : ce qui ne roule pas, et quand si ce n'est pas maintenant. */
        val headline: String,
        /** Jusqu'à quand, ou ce qui roule en attendant. */
        val detail: String?,
        /** Écart signalé dans les dates de TCL. */
        val note: String?,
        /** Schéma de la ligne, vide quand seuls des arrêts sont fermés. */
        val diagram: List<DiagramStop>,
        /** Pastille d'état de la fiche quand la coupure est en cours : « Ne circule pas », « En partie coupé ». */
        val status: String?
    )

    /** Blocs de la fiche d'une ligne : ses coupures en cours, puis la prochaine annoncée. */
    fun lineBlocks(file: NetworkCutsFile?, line: String, nowEpoch: Long): List<LineBlock> {
        if (file == null || !isFresh(file, nowEpoch)) return emptyList()
        val timed = all(file).filter { it.ligne.equals(line, ignoreCase = true) }
            .mapNotNull { cut -> timing(cut, nowEpoch)?.let { cut to it } }
            .sortedBy { it.second.window.start }
        val now = timed.filter { it.second.phase == Phase.NOW }
        val next = timed.firstOrNull { it.second.phase != Phase.NOW }
        return (now + listOfNotNull(next)).map { (cut, timing) -> lineBlock(cut, timing, nowEpoch, runningNow = now.isEmpty()) }
    }

    private fun lineBlock(cut: NetworkCut, timing: Timing, nowEpoch: Long, runningNow: Boolean): LineBlock {
        val subject = subject(cut)
        val shape = shape(cut)
        val window = timing.window
        val headline: String
        val detail: String?
        if (timing.phase == Phase.NOW) {
            headline = "$subject ${shape.present}."
            detail = if (cut.partialTimes) "À certaines heures que TCL ne précise pas, ${untilText(window.end, nowEpoch)}."
                else "${capitalize(untilText(window.end, nowEpoch))}."
        } else {
            val windows = remainingWindows(cut, nowEpoch)
            headline = "${capitalize(whenText(windows, timing, nowEpoch))}, ${subject.replaceFirstChar { it.lowercase() }} ${shape.future}."
            detail = if (runningNow) "En ce moment, il circule sur toute la ligne." else null
        }
        return LineBlock(
            cut = cut,
            phase = timing.phase,
            headline = headline,
            detail = detail,
            note = if (cut.conflictingDates) "Le titre de l'alerte de TCL cite d'autres jours que ses dates officielles, qui sont celles indiquées ici." else null,
            diagram = diagram(cut),
            status = if (timing.phase == Phase.NOW && !cut.partialTimes) (if (cut.wholeLine) "Ne circule pas" else "En partie coupé") else null
        )
    }

    // ── Feuille Trafic : coupures annoncées ──────────────────────────────────

    data class UpcomingRow(val cut: NetworkCut, val title: String, val subtitle: String)
    data class UpcomingGroup(val title: String, val rows: List<UpcomingRow>)

    /**
     * Ce que TCL a déjà publié pour plus tard, regroupé par jours. Ce qui est coupé en ce moment n'y est
     * pas : c'est sur la carte. Une coupure de plusieurs jours n'est listée qu'une fois, à son premier jour.
     */
    fun upcoming(file: NetworkCutsFile?, nowEpoch: Long): List<UpcomingGroup> {
        if (file == null || !isFresh(file, nowEpoch)) return emptyList()
        val rows = all(file).mapNotNull { cut ->
            val timing = timing(cut, nowEpoch)?.takeIf { it.phase != Phase.NOW } ?: return@mapNotNull null
            val windows = remainingWindows(cut, nowEpoch)
            Triple(groupTitle(windows, nowEpoch), timing.window.start, UpcomingRow(cut, capitalize(shape(cut).short), rowSubtitle(windows, cut, nowEpoch)))
        }
        return rows.groupBy { it.first }
            .map { (title, entries) -> entries.minOf { it.second } to UpcomingGroup(title, entries.sortedWith(compareBy({ TransportMode.detectFromLine(it.third.cut.ligne).sortOrder }, { it.third.cut.ligne })).map { it.third }) }
            .sortedBy { it.first }
            .map { it.second }
    }

    private fun groupTitle(windows: List<CutWindow>, nowEpoch: Long): String {
        val first = windows.first()
        if (spansDays(first)) return "À partir ${dayPhrase(serviceDate(first.start), nowEpoch, withDe = true)}"
        return capitalize(dayList(windows.map { serviceDate(it.start) }.distinct(), nowEpoch))
    }

    private fun rowSubtitle(windows: List<CutWindow>, cut: NetworkCut, nowEpoch: Long): String {
        val first = windows.first()
        if (cut.partialTimes) return "À certaines heures, ${untilText(windows.last().end, nowEpoch)}"
        val from = if (startsWithService(first.start)) "Toute la journée" else "Dès ${hour(first.start)}"
        return when {
            spansDays(first) -> "$from, ${untilText(first.end, nowEpoch)}"
            first.end != null && !endsWithService(first.end) -> if (startsWithService(first.start)) "Jusqu'à ${hour(first.end)}" else "De ${hour(first.start)} à ${hour(first.end)}"
            else -> from
        }
    }

    // ── Phrases ──────────────────────────────────────────────────────────────

    /** « Le métro B », « Le tram T3 », « Le bus 38 ». */
    fun subject(cut: NetworkCut): String {
        val noun = when {
            cut.ligne.equals("RX", ignoreCase = true) -> return "Le Rhônexpress"
            cut.mode == "metro" && cut.ligne.uppercase().startsWith("F") -> "funiculaire"
            cut.mode == "metro" -> "métro"
            cut.mode == "tram" -> "tram"
            cut.mode == "trambus" -> "trambus"
            else -> "bus"
        }
        return "Le $noun ${cut.ligne}"
    }

    private data class Shape(val present: String, val future: String, val short: String)

    private fun shape(cut: NetworkCut): Shape {
        if (cut.wholeLine) return Shape("ne circule pas sur toute la ligne", "ne circulera pas", "ne circule pas")
        val direction = cut.directions.singleOrNull()
        val towards = direction?.let { cut.destinations[it] }?.let { " vers $it" }.orEmpty()
        if (cut.traces.isEmpty()) {
            val names = cut.stops.map { it.name }.distinct()
            val list = if (names.size <= 3) joinNames(names) else "${names.size} de ses arrêts"
            return Shape("ne dessert pas $list$towards", "ne desservira pas $list$towards", "ne dessert pas $list$towards")
        }
        val (from, to, between) = section(cut)
        val span = if (between) "entre $from et $to" else "de $from à $to"
        return Shape("ne circule pas $span$towards", "ne circulera pas $span$towards", "coupé $span$towards")
    }

    /** Bornes du tronçon coupé : deux arrêts desservis qui l'encadrent, ou un arrêt desservi et le bout de la coupure. */
    private fun section(cut: NetworkCut): Triple<String, String, Boolean> {
        val bounds = cut.bounds.distinctBy { it.name }
        if (bounds.size >= 2) return Triple(bounds[0].name, bounds[1].name, true)
        val stops = cut.stops.distinctBy { it.name }
        val bound = bounds.firstOrNull()
        if (bound == null || stops.isEmpty()) return Triple(stops.firstOrNull()?.name ?: cut.ligne, stops.lastOrNull()?.name ?: cut.ligne, false)
        val farthest = stops.maxBy { fastDistance2D(it.coordinate, bound.coordinate) }
        return Triple(bound.name, farthest.name, false)
    }

    private fun diagram(cut: NetworkCut): List<DiagramStop> {
        if (cut.traces.isEmpty() && !cut.wholeLine) return emptyList()
        val direction = cut.traces.firstOrNull()?.direction ?: cut.stops.firstOrNull()?.direction ?: return emptyList()
        val stops = cut.stops.filter { it.direction == direction }.distinctBy { it.name }
        if (cut.wholeLine) {
            if (stops.isEmpty()) return emptyList()
            val picks = listOf(stops.first(), stops[stops.size / 2], stops.last()).distinctBy { it.name }
            return picks.mapIndexed { i, s -> DiagramStop(s.name, cut = true, bound = false, gapAfter = i < picks.lastIndex, cutAfter = i < picks.lastIndex) }
        }
        val bounds = cut.bounds.filter { it.direction == direction }.ifEmpty { cut.bounds }.distinctBy { it.name }
        if (stops.isEmpty() || bounds.isEmpty()) return emptyList()
        val origin = cut.destinations[opposite(direction)]
        val destination = cut.destinations[direction]
        if (bounds.size >= 2) {
            return listOfNotNull(
                origin?.let { DiagramStop(it, cut = false, bound = false, gapAfter = true, cutAfter = false) },
                DiagramStop(bounds[0].name, cut = false, bound = true, gapAfter = false, cutAfter = true),
                DiagramStop(stops.first().name, cut = true, bound = false, gapAfter = stops.size > 1, cutAfter = true),
                DiagramStop(bounds[1].name, cut = false, bound = true, gapAfter = destination != null, cutAfter = false),
                destination?.let { DiagramStop(it, cut = false, bound = false, gapAfter = false, cutAfter = false) }
            ).distinctBy { it.name }
        }
        val bound = bounds[0]
        val boundFirst = fastDistance2D(bound.coordinate, stops.first().coordinate) <= fastDistance2D(bound.coordinate, stops.last().coordinate)
        val cutStops = listOf(stops.first(), stops.last()).distinctBy { it.name }
        val nodes = if (boundFirst) {
            listOfNotNull(origin?.let { DiagramStop(it, cut = false, bound = false, gapAfter = true, cutAfter = false) }) +
                DiagramStop(bound.name, cut = false, bound = true, gapAfter = false, cutAfter = true) +
                cutStops.mapIndexed { i, s -> DiagramStop(s.name, cut = true, bound = false, gapAfter = i < cutStops.lastIndex, cutAfter = i < cutStops.lastIndex) }
        } else {
            cutStops.mapIndexed { i, s -> DiagramStop(s.name, cut = true, bound = false, gapAfter = i < cutStops.lastIndex, cutAfter = true) } +
                DiagramStop(bound.name, cut = false, bound = true, gapAfter = destination != null, cutAfter = false) +
                listOfNotNull(destination?.let { DiagramStop(it, cut = false, bound = false, gapAfter = false, cutAfter = false) })
        }
        return nodes.distinctBy { it.name }
    }

    /** « Ce soir, dès 21 h 20 », « Lundi 23 et mardi 24 novembre, dès 21 h 20 », « À partir du lundi 23 novembre ». */
    private fun whenText(windows: List<CutWindow>, timing: Timing, nowEpoch: Long): String {
        val first = timing.window
        if (spansDays(first)) {
            val from = "à partir ${dayPhrase(serviceDate(first.start), nowEpoch, withDe = true)}"
            return if (startsWithService(first.start)) from else "$from, dès ${hour(first.start)}"
        }
        val days = if (timing.phase == Phase.LATER_TODAY) dayPart(first.start) else dayList(windows.map { serviceDate(it.start) }.distinct(), nowEpoch)
        return if (startsWithService(first.start)) days else "$days, dès ${hour(first.start)}"
    }

    /** « jusqu'à 13 h », « jusqu'à la fin du service », « jusqu'au 30 mars inclus ». */
    fun untilText(end: Long?, nowEpoch: Long): String {
        if (end == null) return "sans date de fin annoncée"
        val endDay = serviceDate(end - 1)
        if (endDay == serviceDate(nowEpoch)) return if (endsWithService(end)) "jusqu'à la fin du service" else "jusqu'à ${hour(end)}"
        return if (endsWithService(end)) "jusqu'au ${dayMonth(endDay)} inclus" else "jusqu'au ${dayMonth(endDay)} à ${hour(end)}"
    }

    private fun spansDays(w: CutWindow): Boolean = w.end == null || serviceDate(w.end - 1) != serviceDate(w.start)
    private fun startsWithService(epoch: Long): Boolean = local(epoch).hour in SERVICE_END_HOUR until SERVICE_START_LATEST_HOUR
    private fun endsWithService(epoch: Long): Boolean = local(epoch).hour < SERVICE_END_HOUR || (local(epoch).hour == SERVICE_END_HOUR && local(epoch).minute == 0)

    /** « ce soir » à partir de 18 h, « cet après-midi » à partir de midi, sinon « aujourd'hui ». */
    private fun dayPart(epoch: Long): String = when (local(epoch).hour) {
        in 18..23 -> "ce soir"
        in 12..17 -> "cet après-midi"
        else -> "aujourd'hui"
    }

    private fun dayList(days: List<LocalDate>, nowEpoch: Long): String {
        val sorted = days.sorted()
        if (sorted.size >= 3 && sorted.zipWithNext().all { (a, b) -> b == a.plus(1, DateTimeUnit.DAY) }) {
            return "du ${dayPhrase(sorted.first(), nowEpoch, withMonth = sorted.first().monthNumber != sorted.last().monthNumber, tomorrowByName = false)} au ${dayPhrase(sorted.last(), nowEpoch, tomorrowByName = false)}"
        }
        val shown = sorted.take(4)
        val parts = shown.mapIndexed { i, d ->
            val nextSameMonth = i < shown.lastIndex && shown[i + 1].monthNumber == d.monthNumber
            dayPhrase(d, nowEpoch, withMonth = !nextSameMonth, tomorrowByName = shown.size == 1)
        }
        val list = joinNames(parts)
        return if (sorted.size > shown.size) "$list, puis d'autres jours" else list
    }

    /** « demain », « lundi 23 novembre » ; [withDe] : « de demain », « du lundi 23 novembre ». */
    private fun dayPhrase(day: LocalDate, nowEpoch: Long, withMonth: Boolean = true, withDe: Boolean = false, tomorrowByName: Boolean = true): String {
        if (tomorrowByName && day == serviceDate(nowEpoch).plus(1, DateTimeUnit.DAY)) return if (withDe) "de demain" else "demain"
        val text = "${WEEKDAYS[day.dayOfWeek.isoDayNumber - 1]} ${dayNumber(day)}" + if (withMonth) " ${MONTHS[day.monthNumber - 1]}" else ""
        return if (withDe) "du $text" else text
    }

    private fun dayMonth(day: LocalDate): String = "${dayNumber(day)} ${MONTHS[day.monthNumber - 1]}"
    private fun dayNumber(day: LocalDate): String = if (day.dayOfMonth == 1) "1er" else day.dayOfMonth.toString()

    /** « 21 h 20 », « 13 h ». */
    fun hour(epoch: Long): String {
        val t = local(epoch)
        return if (t.minute == 0) "${t.hour} h" else "${t.hour} h ${t.minute.toString().padStart(2, '0')}"
    }

    private fun joinNames(names: List<String>): String = when (names.size) {
        0 -> ""
        1 -> names[0]
        else -> names.dropLast(1).joinToString(", ") + " et " + names.last()
    }

    private fun capitalize(text: String): String = text.replaceFirstChar { it.uppercase() }
    private fun opposite(direction: String): String = if (direction == "A") "R" else "A"
    private fun local(epoch: Long): LocalDateTime = Instant.fromEpochSeconds(epoch).toLocalDateTime(TimeZone.of(TIME_ZONE))

    /** Journée de service : avant 4 h du matin, c'est encore la veille. */
    private fun serviceDate(epoch: Long): LocalDate {
        val t = local(epoch)
        return if (t.hour < SERVICE_END_HOUR) t.date.plus(-1, DateTimeUnit.DAY) else t.date
    }

    private val WEEKDAYS = listOf("lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche")
    private val MONTHS = listOf("janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre")
}
