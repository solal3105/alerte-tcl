package com.alertetcl.android.ui.live

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EventBusy
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.ui.components.LineBadge
import androidx.compose.material.icons.filled.Warning
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.TimetableTexts
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.LineTimetable
import com.alertetcl.shared.models.TimetableCall
import com.alertetcl.shared.models.TimetableDeparture
import com.alertetcl.shared.models.TimetableDirectionSummary
import com.alertetcl.shared.models.TimetableIndex
import com.alertetcl.shared.models.TimetableLineSummary
import com.alertetcl.shared.models.TimetableTime
import com.alertetcl.shared.services.LineTermini
import com.alertetcl.shared.services.TimetableService
import com.alertetcl.shared.util.AppLogger
import com.alertetcl.shared.util.DemoShowcase
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.first
import kotlinx.datetime.Clock
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

// Fiches horaires théoriques : recherche d'une ligne, choix du sens et de l'arrêt, passages
// d'une journée, détail d'une course. Données : TimetableService (cf. horaires/README.md).
// Parité iOS : TimetableViews.swift. Les couleurs de ligne viennent de la palette officielle
// (LineColors, alimentée par l'index des fiches).

/** Point d'entrée de la boîte de dialogue des horaires. */
sealed class TimetableStart {
    /** Depuis le bouton « Fiches horaires » de la carte : on commence par choisir une ligne. */
    data object Search : TimetableStart()

    /** Depuis la carte « ligne + destination » de la fiche d'un arrêt. */
    data class ForStop(val line: String, val destination: String, val stopIds: Set<Int>, val stopName: String) : TimetableStart()
}

private sealed class TimetableScreen {
    data object Search : TimetableScreen()
    data class Resolving(val request: TimetableStart.ForStop) : TimetableScreen()
    data class Directions(val line: TimetableLineSummary) : TimetableScreen()
    data class Stops(val line: String, val direction: TimetableDirectionSummary) : TimetableScreen()
    data class StopTimes(val timetable: LineTimetable, val stopIndexes: List<Int>, val stopName: String) : TimetableScreen()
    data class Trip(val timetable: LineTimetable, val tripIndex: Int, val stopIndex: Int) : TimetableScreen()
}

private const val MILLIS_PER_DAY = 86_400_000L

private fun serviceDateNow(): LocalDate =
    TimetableTime.serviceDate(Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault()))

private fun serviceMinutesNow(): Int =
    TimetableTime.serviceMinutes(Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault()))

private val longDateFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("EEEE d MMMM yyyy", Locale.FRENCH)

private fun LocalDate.formatLong(): String =
    java.time.LocalDate.of(year, monthNumber, dayOfMonth).format(longDateFormatter)
        .replaceFirstChar { it.uppercase() }

/** Libellé du mode de transport tel que l'index le nomme (metro, tram, bus…). */
private fun modeLabel(mode: String): String = when (mode) {
    "metro" -> "Métro"
    "funicular" -> "Funiculaire"
    "tram" -> "Tramway"
    "trambus" -> "Trambus"
    "trolleybus" -> "Trolleybus"
    "ferry" -> "Navette fluviale"
    else -> "Bus"
}

@Composable
private fun lineColor(line: String): Color = colorFromHex(LineColors.backgroundHex(line))

/** Avertissement quand les fiches n'ont pas pu être renouvelées (même texte que sur iOS). */
@Composable
private fun StaleNotice(text: String) {
    Surface(
        color = Tokens.warning.copy(alpha = 0.12f),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Row(modifier = Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.Warning, null, tint = Tokens.warning, modifier = Modifier.size(20.dp))
            Text(text, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimetableDialog(start: TimetableStart, onDismiss: () -> Unit) {
    val stack = remember(start) {
        mutableStateListOf<TimetableScreen>(
            when (start) {
                is TimetableStart.Search -> TimetableScreen.Search
                is TimetableStart.ForStop -> TimetableScreen.Resolving(start)
            }
        )
    }
    val current = stack.last()
    fun push(screen: TimetableScreen) { stack.add(screen) }
    fun replace(screen: TimetableScreen) { stack[stack.lastIndex] = screen }
    fun back() { if (stack.size > 1) stack.removeAt(stack.lastIndex) else onDismiss() }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        BackHandler { back() }
        Scaffold(
            containerColor = MaterialTheme.colorScheme.surface,
            topBar = {
                TopAppBar(
                    title = { Text(screenTitle(current), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    navigationIcon = {
                        IconButton(onClick = { back() }) {
                            if (stack.size > 1) Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour")
                            else Icon(Icons.Filled.Close, "Fermer")
                        }
                    }
                )
            }
        ) { padding ->
            Box(Modifier.padding(padding).fillMaxSize()) {
                when (val screen = current) {
                    is TimetableScreen.Search -> LineSearchScreen(onSelectLine = { line ->
                        val only = line.directions.singleOrNull()
                        push(if (only != null) TimetableScreen.Stops(line.line, only) else TimetableScreen.Directions(line))
                    })
                    is TimetableScreen.Resolving -> ResolvingScreen(screen.request) { timetable, indexes ->
                        replace(TimetableScreen.StopTimes(timetable, indexes, screen.request.stopName))
                    }
                    is TimetableScreen.Directions -> DirectionsScreen(screen.line) { direction ->
                        push(TimetableScreen.Stops(screen.line.line, direction))
                    }
                    is TimetableScreen.Stops -> StopsScreen(screen.line, screen.direction) { timetable, stopIndex ->
                        push(TimetableScreen.StopTimes(timetable, listOf(stopIndex), timetable.stops[stopIndex].name))
                    }
                    is TimetableScreen.StopTimes -> StopTimesScreen(screen.timetable, screen.stopIndexes, screen.stopName) { departure ->
                        push(TimetableScreen.Trip(screen.timetable, departure.tripIndex, departure.stopIndex))
                    }
                    is TimetableScreen.Trip -> TripScreen(screen.timetable, screen.tripIndex, screen.stopIndex)
                }
            }
        }
    }
}

private fun screenTitle(screen: TimetableScreen): String = when (screen) {
    is TimetableScreen.Search -> "Fiches horaires"
    is TimetableScreen.Resolving -> "Horaires"
    is TimetableScreen.Directions -> "Ligne ${screen.line.line}"
    is TimetableScreen.Stops -> "${screen.line} vers ${screen.direction.headsign}"
    is TimetableScreen.StopTimes -> "Horaires"
    is TimetableScreen.Trip -> "Course ${screen.timetable.line}"
}

// ── Recherche d'une ligne ────────────────────────────────────────────────

@Composable
private fun LineSearchScreen(onSelectLine: (TimetableLineSummary) -> Unit) {
    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())
    var attempt by remember { mutableStateOf(0) }
    var query by remember { mutableStateOf("") }
    val index = produceState<Result<TimetableIndex>?>(initialValue = null, attempt) {
        value = try {
            Result.success(TimetableService.shared.fetchIndex())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppLogger.warn("Index des fiches horaires : ${e.message}")
            Result.failure(e)
        }
    }

    // Modes démo « horaires-ligne » / « horaires-arrets » : ouvrir directement une ligne à deux sens.
    LaunchedEffect(index.value) {
        if (DemoShowcase.current in setOf("horaires-ligne", "horaires-arrets")) {
            index.value?.getOrNull()?.lines?.firstOrNull { it.directions.size == 2 }?.let(onSelectLine)
        }
    }
    when (val result = index.value) {
        null -> LoadingBox("Chargement des lignes…")
        else -> result.fold(
            onSuccess = { loaded ->
                val trimmed = query.trim()
                val filtered = loaded.lines.filter { line ->
                    trimmed.isEmpty() || line.line.contains(trimmed, ignoreCase = true) ||
                        line.directions.any { it.headsign.contains(trimmed, ignoreCase = true) }
                }
                val favoriteLines = filtered.filter { it.line in favorites }
                val otherLines = filtered.filter { it.line !in favorites }
                // Lignes groupées par mode, dans l'ordre de l'index (métro, funiculaire, tram, bus…)
                val byMode = otherLines.groupBy { it.mode }
                LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
                    item { SearchField(query, "Rechercher une ligne ou un terminus…") { query = it } }
                    if (loaded.isStaleOn(serviceDateNow())) {
                        item { StaleNotice(TimetableTexts.staleNotice(loaded.validToDate.formatLong().lowercase())) }
                    }
                    if (favoriteLines.isNotEmpty()) {
                        item {
                            Row(
                                modifier = Modifier.padding(start = 20.dp, top = 12.dp, bottom = 6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(Icons.Filled.Star, null, tint = Color(0xFFFFCC00), modifier = Modifier.size(14.dp))
                                SectionLabel("Favoris")
                            }
                        }
                        items(favoriteLines, key = { "fav_${it.key}" }) { LineRow(it) { onSelectLine(it) } }
                    }
                    byMode.forEach { (mode, lines) ->
                        item(key = "mode_$mode") {
                            SectionLabel(modeLabel(mode), Modifier.padding(start = 20.dp, top = 18.dp, bottom = 6.dp))
                        }
                        items(lines, key = { it.key }) { LineRow(it) { onSelectLine(it) } }
                    }
                    if (filtered.isEmpty()) {
                        item { EmptyText("Aucune ligne ne correspond à cette recherche.") }
                    }
                    item {
                        Text(
                            "Horaires théoriques SYTRAL, connus jusqu'au ${LocalDate.parse(loaded.validTo).formatLong().lowercase()}.",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp)
                        )
                    }
                }
            },
            onFailure = {
                UnavailableBox("Impossible de charger la liste des lignes pour le moment.") { attempt++ }
            }
        )
    }
}

@Composable
private fun LineRow(line: TimetableLineSummary, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 20.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        LineBadge(line.line, size = 36.dp, fontSize = if (line.line.length > 3) 10.sp else 13.sp)
        Text(
            line.directions.joinToString(" ↔ ") { it.headsign },
            style = MaterialTheme.typography.bodyMedium, maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        Chevron()
    }
    HorizontalDivider(modifier = Modifier.padding(start = 70.dp), color = MaterialTheme.colorScheme.outlineVariant)
}

// ── Résolution depuis un arrêt ───────────────────────────────────────────

@Composable
private fun ResolvingScreen(request: TimetableStart.ForStop, onResolved: (LineTimetable, List<Int>) -> Unit) {
    var attempt by remember { mutableStateOf(0) }
    var message by remember { mutableStateOf<String?>(null) }
    var canRetry by remember { mutableStateOf(false) }
    LaunchedEffect(attempt) {
        message = null
        try {
            val termini = LineTermini.all()
            val timetable = TimetableService.shared.findForStop(request.line, request.destination, request.stopIds, request.stopName, termini)
            if (timetable == null) {
                message = "La ligne ${request.line} n'a pas de fiche horaire publiée."
                return@LaunchedEffect
            }
            val indexes = timetable.stopIndexes(request.stopIds, request.stopName)
            if (indexes.isEmpty()) {
                message = "L'arrêt ${request.stopName} n'apparaît pas dans la fiche horaire de la ligne ${request.line} vers ${request.destination}."
                return@LaunchedEffect
            }
            onResolved(timetable, indexes)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppLogger.warn("Fiche horaire ${request.line} : ${e.message}")
            message = "Impossible de charger les horaires pour le moment."
            canRetry = true
        }
    }
    val current = message
    if (current == null) LoadingBox("Chargement des horaires…")
    else UnavailableBox(current, onRetry = if (canRetry) ({ attempt++ }) else null)
}

// ── Choix du sens ────────────────────────────────────────────────────────

@Composable
private fun DirectionsScreen(line: TimetableLineSummary, onSelect: (TimetableDirectionSummary) -> Unit) {
    val accent = lineColor(line.line)
    // Mode démo « horaires-arrets » : ouvrir la liste des arrêts du premier sens.
    LaunchedEffect(Unit) {
        if (DemoShowcase.current == "horaires-arrets") line.directions.firstOrNull()?.let(onSelect)
    }
    LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
        item {
            LineHeaderCard(line.line, "Ligne ${line.line}", modeLabel(line.mode))
            SectionLabel("Dans quel sens ?", Modifier.padding(start = 20.dp, top = 8.dp, bottom = 6.dp))
        }
        items(line.directions, key = { it.dir }) { direction ->
            Row(
                modifier = Modifier.fillMaxWidth().clickable { onSelect(direction) }.padding(horizontal = 20.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Box(
                    modifier = Modifier.size(32.dp).clip(CircleShape).background(accent.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = accent, modifier = Modifier.size(18.dp)) }
                Column(modifier = Modifier.weight(1f)) {
                    Text("Vers ${direction.headsign}", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
                    Text("${direction.stops} arrêts", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Chevron()
            }
            HorizontalDivider(modifier = Modifier.padding(start = 66.dp), color = MaterialTheme.colorScheme.outlineVariant)
        }
    }
}

// ── Choix de l'arrêt ─────────────────────────────────────────────────────

@Composable
private fun StopsScreen(line: String, direction: TimetableDirectionSummary, onSelectStop: (LineTimetable, Int) -> Unit) {
    var attempt by remember { mutableStateOf(0) }
    var query by remember { mutableStateOf("") }
    val loaded = produceState<Result<LineTimetable>?>(initialValue = null, line, direction.dir, attempt) {
        value = try {
            Result.success(TimetableService.shared.fetchLine(line, direction.dir))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppLogger.warn("Fiche $line/${direction.dir} : ${e.message}")
            Result.failure(e)
        }
    }
    when (val result = loaded.value) {
        null -> LoadingBox("Chargement de la ligne…")
        else -> result.fold(
            onSuccess = { timetable ->
                val accent = lineColor(timetable.line)
                val trimmed = query.trim()
                val indexes = timetable.stops.indices.filter { trimmed.isEmpty() || timetable.stops[it].name.contains(trimmed, ignoreCase = true) }
                LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
                    item {
                        LineHeaderCard(timetable.line, "Vers ${timetable.headsign}", "${timetable.stops.size} arrêts dans l'ordre du parcours")
                        SearchField(query, "Rechercher un arrêt…") { query = it }
                    }
                    items(indexes, key = { it }) { stopIndex ->
                        val stop = timetable.stops[stopIndex]
                        val isEnd = stopIndex == 0 || stopIndex == timetable.stops.lastIndex
                        Row(
                            modifier = Modifier.fillMaxWidth().clickable { onSelectStop(timetable, stopIndex) }.padding(horizontal = 20.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Rail de la ligne : les arrêts s'enchaînent visuellement comme sur un plan
                            TimelineDot(accent, isEnd = isEnd, highlighted = false, showAbove = stopIndex > 0 && trimmed.isEmpty(), showBelow = stopIndex < timetable.stops.lastIndex && trimmed.isEmpty())
                            Text(
                                stop.name,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = if (isEnd) FontWeight.SemiBold else FontWeight.Normal,
                                modifier = Modifier.weight(1f).padding(vertical = 13.dp, horizontal = 12.dp)
                            )
                            Chevron()
                        }
                    }
                    if (indexes.isEmpty()) item { EmptyText("Aucun arrêt ne correspond à cette recherche.") }
                }
            },
            onFailure = { UnavailableBox("Impossible de charger la fiche de la ligne $line pour le moment.") { attempt++ } }
        )
    }
}

// ── Passages d'une journée à un arrêt ───────────────────────────────────

private sealed class TimesRow {
    data class Hour(val hour: Int) : TimesRow()
    data class Departure(val departure: TimetableDeparture) : TimesRow()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StopTimesScreen(
    timetable: LineTimetable,
    stopIndexes: List<Int>,
    stopName: String,
    onSelectTrip: (TimetableDeparture) -> Unit
) {
    val accent = lineColor(timetable.line)
    val today = remember { serviceDateNow() }
    // Fiche périmée : on montre le dernier jour connu, avec un avertissement dans la liste.
    var date by remember(timetable) {
        mutableStateOf(
            when {
                timetable.isValidOn(today) -> today
                timetable.isStaleOn(today) -> timetable.validToDate
                else -> timetable.validFromDate
            }
        )
    }
    var showPicker by remember { mutableStateOf(false) }
    val departures = remember(timetable, stopIndexes, date) { timetable.departures(stopIndexes, date) }
    val isServiceDay = date == today
    val nowMinutes = remember(isServiceDay) { serviceMinutesNow() }
    val nextId = remember(departures, isServiceDay, nowMinutes) {
        if (isServiceDay) departures.firstOrNull { it.minutes >= nowMinutes }?.let { "${it.tripIndex}-${it.stopIndex}" } else null
    }
    val rows = remember(departures) {
        buildList {
            var lastHour = -1
            for (d in departures) {
                val hour = d.minutes / 60
                if (hour != lastHour) { add(TimesRow.Hour(hour)); lastHour = hour }
                add(TimesRow.Departure(d))
            }
        }
    }
    // Mode démo « horaires-course » : ouvrir le détail du prochain passage.
    LaunchedEffect(nextId) {
        if (DemoShowcase.current == "horaires-course") {
            departures.firstOrNull { "${it.tripIndex}-${it.stopIndex}" == nextId }?.let(onSelectTrip)
        }
    }
    val listState: LazyListState = rememberLazyListState()
    // Ouvre la liste sur le prochain passage (journée en cours), centré dans la fenêtre
    // une fois la hauteur visible connue (première mise en page).
    LaunchedEffect(rows, nextId) {
        val target = rows.indexOfFirst { it is TimesRow.Departure && "${it.departure.tripIndex}-${it.departure.stopIndex}" == nextId }
        if (target < 0) return@LaunchedEffect
        val viewportHeight = snapshotFlow { listState.layoutInfo.viewportEndOffset }.first { it > 0 }
        listState.scrollToItem(target, scrollOffset = -viewportHeight / 2)
    }

    Column(Modifier.fillMaxSize()) {
    // L'en-tête reste visible : la liste seule défile jusqu'au prochain passage.
    LineHeaderCard(timetable.line, "Vers ${timetable.headsign}", "Arrêt $stopName") {
        Text(date.formatLong(), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
            DayChip("Aujourd'hui", today, date, timetable, accent) { date = it }
            DayChip("Demain", today.plus(1, DateTimeUnit.DAY), date, timetable, accent) { date = it }
            FilterChip(
                selected = false,
                onClick = { showPicker = true },
                label = { Text("Autre jour") },
                leadingIcon = { Icon(Icons.Filled.CalendarMonth, null, modifier = Modifier.size(16.dp)) }
            )
        }
    }
    LazyColumn(state = listState, contentPadding = PaddingValues(bottom = 24.dp), modifier = Modifier.weight(1f)) {
        if (timetable.isStaleOn(today)) {
            item { StaleNotice(TimetableTexts.staleNotice(timetable.validToDate.formatLong().lowercase())) }
        }
        if (departures.isEmpty()) {
            item { EmptyText("Aucun passage prévu ce jour-là à cet arrêt.") }
        }
        items(rows) { row ->
            when (row) {
                is TimesRow.Hour -> SectionLabel(
                    if (row.hour < 24) "${row.hour} h" else "${row.hour - 24} h, après minuit",
                    Modifier.padding(start = 20.dp, top = 16.dp, bottom = 4.dp)
                )
                is TimesRow.Departure -> DepartureRow(row.departure, timetable, accent,
                    isPast = isServiceDay && row.departure.minutes < nowMinutes,
                    isNext = "${row.departure.tripIndex}-${row.departure.stopIndex}" == nextId,
                    onClick = { onSelectTrip(row.departure) })
            }
        }
        item {
            Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "Horaires théoriques publiés par SYTRAL, connus jusqu'au ${timetable.validToDate.formatLong().lowercase()}. Ils ne tiennent pas compte des perturbations du jour : consultez les alertes trafic.",
                    style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (departures.any { TimetableTime.isAfterMidnight(it.minutes) }) {
                    Text(
                        "Les passages après minuit sont rattachés à la journée de service de la veille.",
                        style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
    }

    if (showPicker) {
        val fromMillis = timetable.validFromDate.toEpochDays() * MILLIS_PER_DAY
        val toMillis = timetable.validToDate.toEpochDays() * MILLIS_PER_DAY
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = date.toEpochDays() * MILLIS_PER_DAY,
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean = utcTimeMillis in fromMillis..toMillis
            }
        )
        DatePickerDialog(
            onDismissRequest = { showPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    pickerState.selectedDateMillis?.let { date = LocalDate.fromEpochDays((it / MILLIS_PER_DAY).toInt()) }
                    showPicker = false
                }) { Text("Voir ce jour") }
            },
            dismissButton = { TextButton(onClick = { showPicker = false }) { Text("Annuler") } }
        ) {
            DatePicker(state = pickerState)
        }
    }
}

@Composable
private fun DepartureRow(
    d: TimetableDeparture, timetable: LineTimetable, accent: Color,
    isPast: Boolean, isNext: Boolean, onClick: () -> Unit
) {
    val textColor = when {
        isNext -> accent
        isPast -> MaterialTheme.colorScheme.onSurfaceVariant
        else -> MaterialTheme.colorScheme.onSurface
    }
    Surface(
        color = if (isNext) accent.copy(alpha = 0.12f) else Color.Transparent,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 8.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                d.time, fontFamily = FontFamily.Monospace, fontSize = 17.sp, color = textColor,
                fontWeight = if (isNext) FontWeight.Bold else FontWeight.Medium
            )
            if (d.terminus != timetable.headsign) {
                Text(
                    "vers ${d.terminus}", style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )
            }
            Spacer(Modifier.weight(1f))
            if (d.isTerminus) Pill("arrivée", MaterialTheme.colorScheme.surfaceVariant, MaterialTheme.colorScheme.onSurfaceVariant)
            if (isNext) Pill("prochain", accent, colorFromHex(LineColors.textHex(timetable.line)))
            Chevron()
        }
    }
    HorizontalDivider(modifier = Modifier.padding(start = 20.dp, end = 12.dp), color = MaterialTheme.colorScheme.outlineVariant)
}

@Composable
private fun DayChip(label: String, target: LocalDate, selected: LocalDate, timetable: LineTimetable, accent: Color, onSelect: (LocalDate) -> Unit) {
    FilterChip(
        selected = target == selected,
        onClick = { onSelect(target) },
        enabled = timetable.isValidOn(target),
        label = { Text(label) },
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = accent.copy(alpha = 0.18f),
            selectedLabelColor = MaterialTheme.colorScheme.onSurface
        )
    )
}

// ── Détail d'une course ──────────────────────────────────────────────────

@Composable
private fun TripScreen(timetable: LineTimetable, tripIndex: Int, highlightedStopIndex: Int) {
    val accent = lineColor(timetable.line)
    val calls = remember(timetable, tripIndex) { timetable.calls(tripIndex) }
    LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
        item {
            LineHeaderCard(
                timetable.line,
                calls.lastOrNull()?.let { "Vers ${it.stop.name}" } ?: "Course ${timetable.line}",
                calls.firstOrNull()?.let { "Départ à ${it.time} de ${it.stop.name}" } ?: ""
            )
            SectionLabel("Arrêts desservis", Modifier.padding(start = 20.dp, top = 8.dp, bottom = 4.dp))
        }
        items(calls, key = { it.position }) { call -> TripCallRow(call, accent, call.stopIndex == highlightedStopIndex, isFirst = call.position == 0, isLast = call.position == calls.lastIndex) }
    }
}

@Composable
private fun TripCallRow(call: TimetableCall, accent: Color, highlighted: Boolean, isFirst: Boolean, isLast: Boolean) {
    val color = if (highlighted) accent else MaterialTheme.colorScheme.onSurface
    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
            call.time, fontFamily = FontFamily.Monospace, fontSize = 15.sp, color = color,
            fontWeight = if (highlighted) FontWeight.Bold else FontWeight.Normal,
            modifier = Modifier.width(56.dp)
        )
        TimelineDot(accent, isEnd = isFirst || isLast, highlighted = highlighted, showAbove = !isFirst, showBelow = !isLast)
        Text(
            call.stop.name, style = MaterialTheme.typography.bodyMedium, color = color,
            fontWeight = if (highlighted || isFirst || isLast) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.padding(vertical = 12.dp, horizontal = 12.dp)
        )
    }
}

// ── Éléments communs ─────────────────────────────────────────────────────

/** Carte d'en-tête : badge de la ligne, titre, sous-titre et contenu libre (date, filtres). */
@Composable
private fun LineHeaderCard(line: String, title: String, subtitle: String, content: (@Composable () -> Unit)? = null) {
    val accent = lineColor(line)
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Column {
            Box(Modifier.fillMaxWidth().height(4.dp).background(accent))
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    LineBadge(line, size = 44.dp, fontSize = if (line.length > 3) 12.sp else 16.sp)
                    Column {
                        Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        if (subtitle.isNotEmpty()) {
                            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                content?.let { Column { it() } }
            }
        }
    }
}

/** Point sur le rail d'une ligne (détail d'une course, liste des arrêts). */
@Composable
private fun TimelineDot(accent: Color, isEnd: Boolean, highlighted: Boolean, showAbove: Boolean, showBelow: Boolean) {
    Box(modifier = Modifier.width(20.dp).height(48.dp), contentAlignment = Alignment.Center) {
        Column(modifier = Modifier.fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.width(3.dp).weight(1f).background(if (showAbove) accent.copy(alpha = 0.35f) else Color.Transparent))
            Box(Modifier.width(3.dp).weight(1f).background(if (showBelow) accent.copy(alpha = 0.35f) else Color.Transparent))
        }
        val size = if (highlighted) 16.dp else if (isEnd) 13.dp else 10.dp
        Box(
            modifier = Modifier.size(size).clip(CircleShape)
                .background(if (highlighted || isEnd) accent else MaterialTheme.colorScheme.surface)
                .padding(if (highlighted || isEnd) 0.dp else 2.dp)
        ) {
            if (!(highlighted || isEnd)) {
                Box(Modifier.fillMaxSize().clip(CircleShape).background(accent.copy(alpha = 0.6f)))
            }
        }
    }
}

@Composable
private fun Pill(text: String, background: Color, foreground: Color) {
    Text(
        text, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, color = foreground,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(background).padding(horizontal = 8.dp, vertical = 3.dp)
    )
}

@Composable
private fun Chevron() {
    Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.size(14.dp))
}

@Composable
private fun SearchField(value: String, placeholder: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value, onValueChange = onChange,
        placeholder = { Text(placeholder, fontSize = 14.sp) },
        leadingIcon = { Icon(Icons.Filled.Search, null, tint = MaterialTheme.colorScheme.onSurfaceVariant) },
        singleLine = true,
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
    )
}

@Composable
private fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(), style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = modifier
    )
}

@Composable
private fun EmptyText(text: String) {
    Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(20.dp))
}

@Composable
private fun LoadingBox(text: String) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            CircularProgressIndicator(modifier = Modifier.size(28.dp), strokeWidth = 2.dp)
            Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun UnavailableBox(message: String, onRetry: (() -> Unit)?) {
    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Icon(Icons.Filled.EventBusy, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(40.dp))
            Text("Horaires indisponibles", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            Text(message, textAlign = TextAlign.Center, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (onRetry != null) {
                Spacer(Modifier.height(4.dp))
                Button(onClick = onRetry) { Text("Réessayer") }
            }
        }
    }
}
