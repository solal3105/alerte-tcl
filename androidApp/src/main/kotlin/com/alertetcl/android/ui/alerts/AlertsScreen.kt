package com.alertetcl.android.ui.alerts

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.add
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsBoat
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.NotificationAdd
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.TextButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import androidx.compose.material3.MaterialTheme
import com.alertetcl.android.ui.components.LineBadge
import com.alertetcl.android.ui.components.SheetHeader
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.AlertDates
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.LineSubscription
import com.alertetcl.shared.models.LineSubscriptions
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransportLine
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.util.DemoShowcase
import com.alertetcl.shared.viewmodels.AlertsViewModel
import kotlinx.coroutines.launch
import com.alertetcl.shared.services.TimetableService
import com.alertetcl.shared.models.LineRegistry



@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlertsScreen(viewModel: AlertsViewModel? = null) {
    // Si un ViewModel est passé (depuis LiveMapScreen), on le réutilise sans le
    // disposer à la fermeture de la sheet — miroir iOS @EnvironmentObject.
    val vm = viewModel ?: remember { AlertsViewModel() }
    DisposableEffect(vm) {
        vm.startPolling()
        onDispose { if (viewModel == null) vm.dispose() }
    }
    val alerts by vm.alerts.collectAsState()
    val isLoading by vm.isLoading.collectAsState()
    val error by vm.errorMessage.collectAsState()
    val lastUpdate by vm.lastUpdate.collectAsState()

    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val scope = rememberCoroutineScope()
    val storedSubscriptions by store.lineSubscriptions.collectAsState(initial = emptyMap())
    // Mode démo : abonnements simulés, jamais enregistrés (cf. DemoShowcase).
    val subscriptions = if (DemoShowcase.isAlertsCase) DemoShowcase.subscriptions() else storedSubscriptions

    // Lignes du réseau lues dans l'index des fiches horaires (régénéré chaque nuit), aucune liste
    // embarquée : une renumérotation n'attend pas une mise à jour de l'application.
    LaunchedEffect(Unit) { runCatching { TimetableService.shared.fetchIndex() } }
    val allLines: List<TransportLine> by LineRegistry.lines.collectAsState()

    val subscribedLines = remember(allLines, subscriptions) {
        LineSubscriptions.subscribedLines(subscriptions, allLines)
    }
    fun updateSubscriptions(transform: (Map<String, LineSubscription>) -> Map<String, LineSubscription>) {
        scope.launch { store.updateLineSubscriptions(transform) }
    }
    val alertsByLine: Map<String, List<TCLAlert>> = remember(alerts) {
        val now = System.currentTimeMillis() / 1000L
        alertsToLineMap(alerts.filter { it.severity != AlertSeverity.INFO && it.isOngoing(now) })
    }
    val allAlertsByLine: Map<String, List<TCLAlert>> = remember(alerts) {
        alertsToLineMap(alerts.filter { it.severity != AlertSeverity.INFO })
    }

    var selectedModeFilter by remember { mutableStateOf<TransportMode?>(null) }
    var subscribeSheetOpen by remember { mutableStateOf(false) }
    var selectedLine by remember { mutableStateOf<TransportLine?>(null) }
    var optionsLine by remember { mutableStateOf<TransportLine?>(null) }
    var refreshing by remember { mutableStateOf(false) }

    if (DemoShowcase.isAlertsCase) {
        LaunchedEffect(Unit) {
            kotlinx.coroutines.delay(1_500)
            val c12 = allLines.firstOrNull { it.ligneCom == "C12" } ?: return@LaunchedEffect
            when (DemoShowcase.current) {
                "alertes-ligne" -> selectedLine = c12
                "alertes-options" -> optionsLine = c12
            }
        }
    }

    PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = {
            refreshing = true
            vm.refresh()
        },
        modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)
    ) {
        LaunchedEffect(isLoading) { if (!isLoading) refreshing = false }

        when {
            allLines.isEmpty() && isLoading -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
            allLines.isEmpty() && error != null -> {
                Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                    Text(error ?: "Impossible de charger les alertes.", textAlign = TextAlign.Center)
                }
            }
            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = WindowInsets.navigationBars
                        .add(WindowInsets(bottom = 96.dp))
                        .asPaddingValues()
                ) {
                    if (subscribedLines.isNotEmpty()) {
                        item {
                            StatusSummaryBanner(
                                subscribedLines = subscribedLines,
                                alertsByLine = alertsByLine,
                                lastUpdate = lastUpdate,
                                modifier = Modifier
                                    .padding(horizontal = 16.dp)
                                    .padding(top = 16.dp)
                            )
                        }
                    }
                    item {
                        MyLinesSection(
                            subscribedLines = subscribedLines,
                            alertsByLine = alertsByLine,
                            onAdd = { subscribeSheetOpen = true },
                            onLineClick = { selectedLine = it },
                            modifier = Modifier.padding(top = 24.dp)
                        )
                    }
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                                .padding(top = 32.dp)
                                .height(0.5.dp)
                                .background(MaterialTheme.colorScheme.outlineVariant)
                        )
                    }
                    item { AllLinesHeader(modifier = Modifier.padding(top = 24.dp)) }
                    item {
                        ModeFilterTabs(
                            allLines = allLines,
                            alertsByLine = alertsByLine,
                            selected = selectedModeFilter,
                            onSelect = { selectedModeFilter = it },
                            modifier = Modifier.padding(top = 14.dp)
                        )
                    }
                    item {
                        LinesGrid(
                            lines = allLines,
                            selectedMode = selectedModeFilter,
                            alertsByLine = alertsByLine,
                            subscriptions = subscriptions,
                            onClick = { selectedLine = it },
                            modifier = Modifier.padding(top = 14.dp, start = 16.dp, end = 16.dp)
                        )
                    }
                }
            }
        }
    }

    if (subscribeSheetOpen) {
        ModalBottomSheet(
            onDismissRequest = { subscribeSheetOpen = false },
            sheetState = rememberModalBottomSheetState(),
            contentWindowInsets = { WindowInsets.systemBars }
        ) {
            SubscribeLineSheet(
                allLines = allLines,
                subscriptions = subscriptions,
                onToggle = { line -> updateSubscriptions { LineSubscriptions.toggle(it, line) } },
                onClose = { subscribeSheetOpen = false }
            )
        }
    }

    selectedLine?.let { line ->
        ModalBottomSheet(
            onDismissRequest = { selectedLine = null },
            sheetState = rememberModalBottomSheetState(),
            contentWindowInsets = { WindowInsets.systemBars }
        ) {
            LineDetailSheet(
                line = line,
                alerts = allAlertsByLine[line.ligneCom].orEmpty(),
                isSubscribed = LineSubscriptions.isSubscribed(subscriptions, line),
                onOptions = { optionsLine = line },
                onUnsubscribe = { updateSubscriptions { LineSubscriptions.unsubscribe(it, line) } },
                onClose = { selectedLine = null }
            )
        }
    }

    optionsLine?.let { line ->
        ModalBottomSheet(
            onDismissRequest = { optionsLine = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            contentWindowInsets = { WindowInsets.systemBars }
        ) {
            SubscriptionOptionsSheet(
                line = line,
                initialTypes = LineSubscriptions.preferences(subscriptions, line),
                onSave = { types ->
                    updateSubscriptions { LineSubscriptions.subscribe(it, line, types) }
                    optionsLine = null
                },
                onCancel = { optionsLine = null }
            )
        }
    }
}

/** Tri naturel : préfixe alphabétique d'abord, puis suffixe numérique ("C10" après "C9").
 *  Gère les suffixes non-numériques (ex. "6E", "C15E", "89D") en extrayant uniquement la
 *  partie numérique de tête — le suffixe alphabétique final est ignoré pour le tri. */
private fun naturalLineOrder(name: String): Pair<String, Int> {
    val idx = name.indexOfFirst { it.isDigit() }
    if (idx < 0) return name to 0
    val prefix = name.substring(0, idx)
    val numStr = name.substring(idx).takeWhile { it.isDigit() }
    return prefix to (numStr.toIntOrNull() ?: 0)
}

/** Indexes [alerts] by both ligneCom and ligneCli for O(1) per-line lookup. */
private fun alertsToLineMap(alerts: List<TCLAlert>): Map<String, List<TCLAlert>> =
    buildMap<String, MutableList<TCLAlert>> {
        alerts.forEach { a ->
            getOrPut(a.ligneCom) { mutableListOf() }.add(a)
            if (a.ligneCli.isNotBlank() && a.ligneCli != a.ligneCom)
                getOrPut(a.ligneCli) { mutableListOf() }.add(a)
        }
    }

// ─── Status Summary Banner ───────────────────────────────────────────────
@Composable
private fun StatusSummaryBanner(
    subscribedLines: List<TransportLine>,
    alertsByLine: Map<String, List<TCLAlert>>,
    lastUpdate: Long?,
    modifier: Modifier = Modifier
) {
    val totalAlerts = subscribedLines.sumOf { alertsByLine[it.ligneCom]?.size ?: 0 }
    val hasMajor = subscribedLines.any { line ->
        alertsByLine[line.ligneCom]?.any { it.severity == AlertSeverity.MAJOR } == true
    }
    val color = when { hasMajor -> Tokens.error; totalAlerts > 0 -> Tokens.warning; else -> Tokens.success }
    val icon: ImageVector = when {
        hasMajor -> Icons.Filled.Warning
        totalAlerts > 0 -> Icons.Filled.NotificationsActive
        else -> Icons.Filled.CheckCircle
    }
    val updateText: String? = lastUpdate?.let { epoch ->
        val elapsed = System.currentTimeMillis() / 1000L - epoch
        when {
            elapsed < 60L -> "il y a quelques secondes"
            elapsed < 3600L -> "il y a ${elapsed / 60} min"
            else -> "il y a ${elapsed / 3600}h"
        }
    }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(color.copy(alpha = 0.10f))
            .border(1.dp, color.copy(alpha = 0.25f), MaterialTheme.shapes.large)
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(
                modifier = Modifier.size(38.dp).clip(CircleShape).background(color),
                contentAlignment = Alignment.Center
            ) { Icon(icon, null, tint = Color.White, modifier = Modifier.size(16.dp)) }

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                if (totalAlerts == 0) {
                    Text("Toutes vos lignes sont normales", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                } else {
                    Text(
                        "$totalAlerts perturbation${if (totalAlerts > 1) "s" else ""} sur vos lignes",
                        style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold
                    )
                }
                if (updateText != null) {
                    Text("Mis à jour $updateText", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

// ─── My Lines Section ────────────────────────────────────────────────────
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MyLinesSection(
    subscribedLines: List<TransportLine>,
    alertsByLine: Map<String, List<TCLAlert>>,
    onAdd: () -> Unit,
    onLineClick: (TransportLine) -> Unit,
    modifier: Modifier = Modifier
) {
    val sorted = remember(subscribedLines, alertsByLine) {
        subscribedLines.sortedWith(
            compareBy<TransportLine> { line ->
                alertsByLine[line.ligneCom]?.minOfOrNull { it.severity.sortOrder } ?: 999
            }.thenBy { it.mode.sortOrder }.thenComparator { a, b ->
                val (ap, an) = naturalLineOrder(a.displayName)
                val (bp, bn) = naturalLineOrder(b.displayName)
                ap.compareTo(bp).takeIf { it != 0 } ?: an.compareTo(bn)
            }
        )
    }

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("Mes lignes", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                if (subscribedLines.isNotEmpty()) {
                    Text(
                        "${subscribedLines.size} abonnement${if (subscribedLines.size > 1) "s" else ""}",
                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            IconButton(
                onClick = onAdd,
                modifier = Modifier.size(30.dp),
                colors = IconButtonDefaults.iconButtonColors(containerColor = MaterialTheme.colorScheme.primary, contentColor = MaterialTheme.colorScheme.onPrimary)
            ) { Icon(Icons.Filled.Add, "Ajouter une ligne", modifier = Modifier.size(16.dp)) }
        }

        if (sorted.isEmpty()) {
            EmptySubscriptionsView(onAdd = onAdd)
        } else {
            val pagerState = rememberPagerState(pageCount = { sorted.size })
            HorizontalPager(
                state = pagerState,
                contentPadding = PaddingValues(horizontal = 16.dp),
                pageSpacing = 12.dp,
                modifier = Modifier.fillMaxWidth().height(152.dp)
            ) { page ->
                val line = sorted[page]
                LineStatusCard(
                    line = line,
                    alerts = alertsByLine[line.ligneCom].orEmpty(),
                    onClick = { onLineClick(line) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
            // Page indicator dots (parité iOS)
            if (sorted.size > 1) {
                Spacer(Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    repeat(sorted.size) { idx ->
                        val isCurrent = pagerState.currentPage == idx
                        Box(
                            modifier = Modifier
                                .padding(horizontal = 3.dp)
                                .size(if (isCurrent) 8.dp else 6.dp)
                                .clip(CircleShape)
                                .background(if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptySubscriptionsView(onAdd: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .clickable { onAdd() }
            .padding(vertical = 40.dp, horizontal = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Box(
                modifier = Modifier.size(72.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.NotificationAdd, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(30.dp))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Suivez vos lignes", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                Text(
                    "Recevez des alertes en temps réel pour les lignes qui vous importent",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.Add, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                Text("S'abonner à une ligne", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun LineStatusCard(
    line: TransportLine,
    alerts: List<TCLAlert>,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val highestSeverity = alerts.minByOrNull { it.severity.sortOrder }?.severity
    val statusColor = when (highestSeverity) {
        AlertSeverity.MAJOR -> Tokens.error
        AlertSeverity.DISRUPTION -> Tokens.warning
        AlertSeverity.INFO -> MaterialTheme.colorScheme.primary
        null -> Tokens.success
    }
    val modeColor = Tokens.mode(line.mode)

    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 6.dp,
        border = androidx.compose.foundation.BorderStroke(1.dp, statusColor.copy(alpha = 0.18f)),
        modifier = modifier.clickable { onClick() }
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.width(5.dp).height(120.dp).background(statusColor))
            Row(
                modifier = Modifier.padding(16.dp).weight(1f),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                LineBadge(line.displayName, size = 62.dp, fontSize = 20.sp)
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(modeColor.copy(alpha = 0.12f))
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    ) {
                        Text(line.mode.displayName, style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold, color = modeColor)
                    }
                    Text("Ligne ${line.displayName}", fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(modifier = Modifier.size(7.dp).clip(CircleShape).background(statusColor))
                        if (alerts.isEmpty()) {
                            Text("Service normal", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        } else {
                            Text(
                                "${alerts.size} perturbation${if (alerts.size > 1) "s" else ""}",
                                fontSize = 13.sp, color = statusColor, fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
                if (alerts.isNotEmpty()) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("${alerts.size}", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black, color = statusColor)
                        Text(if (alerts.size > 1) "alertes" else "alerte",
                            fontSize = 10.sp, fontWeight = FontWeight.Bold, color = statusColor.copy(alpha = 0.65f))
                    }
                } else {
                    Icon(Icons.Filled.CheckCircle, null, tint = Tokens.success, modifier = Modifier.size(28.dp))
                }
            }
        }
    }
}

// ─── All Lines section ───────────────────────────────────────────────────
@Composable
private fun AllLinesHeader(modifier: Modifier = Modifier) {
    Row(modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        Text("Toutes les lignes", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun ModeFilterTabs(
    allLines: List<TransportLine>,
    alertsByLine: Map<String, List<TCLAlert>>,
    selected: TransportMode?,
    onSelect: (TransportMode?) -> Unit,
    modifier: Modifier = Modifier
) {
    val availableModes = remember(allLines) {
        TransportMode.entries.filter { mode -> allLines.any { it.mode == mode } }.sortedBy { it.sortOrder }
    }
    val totalAlerts = alertsByLine.values.sumOf { it.size }
    val countByMode: Map<TransportMode, Int> = remember(allLines, alertsByLine) {
        val map = mutableMapOf<TransportMode, Int>()
        allLines.forEach { line ->
            val n = alertsByLine[line.ligneCom]?.size ?: 0
            if (n > 0) map[line.mode] = (map[line.mode] ?: 0) + n
        }
        map
    }
    Row(
        modifier = modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        ModeChip(label = "Tout", icon = Icons.Filled.Apps, color = MaterialTheme.colorScheme.onSurfaceVariant,
            onColor = MaterialTheme.colorScheme.surface,
            badgeCount = totalAlerts,
            isSelected = selected == null) { onSelect(null) }
        availableModes.forEach { mode ->
            ModeChip(
                label = mode.displayName,
                icon = transportModeIcon(mode),
                color = Tokens.mode(mode),
                onColor = transportModeOnColor(mode),
                badgeCount = countByMode[mode] ?: 0,
                isSelected = selected == mode
            ) { onSelect(mode) }
        }
    }
}

@Composable
private fun ModeChip(label: String, icon: ImageVector, color: Color, onColor: Color = Color.White, badgeCount: Int = 0, isSelected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (isSelected) color else color.copy(alpha = 0.12f))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 7.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon(icon, null, tint = if (isSelected) onColor else color, modifier = Modifier.size(11.dp))
            Text(label, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold,
                color = if (isSelected) onColor else color)
            if (badgeCount > 0) {
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (isSelected) onColor else color)
                        .padding(horizontal = 6.dp, vertical = 1.dp)
                ) {
                    Text("$badgeCount", fontSize = 10.sp, fontWeight = FontWeight.Bold,
                        color = if (isSelected) color else onColor)
                }
            }
        }
    }
}

@Composable
private fun LinesGrid(
    lines: List<TransportLine>,
    selectedMode: TransportMode?,
    alertsByLine: Map<String, List<TCLAlert>>,
    subscriptions: Map<String, LineSubscription>,
    onClick: (TransportLine) -> Unit,
    modifier: Modifier = Modifier
) {
    val filtered = remember(lines, selectedMode) {
        val base = if (selectedMode != null) lines.filter { it.mode == selectedMode } else lines
        base.sortedWith(
            compareBy<TransportLine> { it.mode.sortOrder }.thenComparator { a, b ->
                val (ap, an) = naturalLineOrder(a.displayName)
                val (bp, bn) = naturalLineOrder(b.displayName)
                ap.compareTo(bp).takeIf { it != 0 } ?: an.compareTo(bn)
            }
        )
    }
    val rows = (filtered.size + 2) / 3
    val cellHeight = 96.dp
    val totalHeight = (cellHeight + 10.dp) * rows
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = modifier.height(totalHeight),
        userScrollEnabled = false
    ) {
        items(filtered, key = { it.id }) { line ->
            LineGridCell(
                line = line,
                alertCount = alertsByLine[line.ligneCom]?.size ?: 0,
                isSubscribed = LineSubscriptions.isSubscribed(subscriptions, line),
                highestSeverity = alertsByLine[line.ligneCom]?.minByOrNull { it.severity.sortOrder }?.severity,
                onClick = { onClick(line) }
            )
        }
    }
}

@Composable
private fun LineGridCell(
    line: TransportLine,
    alertCount: Int,
    isSubscribed: Boolean,
    highestSeverity: AlertSeverity?,
    onClick: () -> Unit
) {
    val modeColor = Tokens.mode(line.mode)
    val badgeColor = when (highestSeverity) {
        AlertSeverity.MAJOR -> Tokens.error
        AlertSeverity.DISRUPTION -> Tokens.warning
        AlertSeverity.INFO -> MaterialTheme.colorScheme.primary
        null -> Tokens.error
    }
    val badgeOnColor = when (highestSeverity) {
        AlertSeverity.DISRUPTION -> Tokens.onLight
        AlertSeverity.INFO       -> MaterialTheme.colorScheme.onPrimary
        else                     -> Color.White
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 96.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(modeColor.copy(alpha = 0.08f))
            .border(
                width = if (isSubscribed) 1.5.dp else 0.5.dp,
                color = modeColor.copy(alpha = if (isSubscribed) 0.45f else 0.15f),
                shape = RoundedCornerShape(14.dp)
            )
            .clickable { onClick() }
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(vertical = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            LineBadge(line.displayName, size = 50.dp, fontSize = 16.sp)
            Text(line.displayName, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, maxLines = 1)
        }
        if (alertCount > 0) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(end = 4.dp)
                    .clip(RoundedCornerShape(50))
                    .background(badgeColor)
                    .padding(horizontal = 5.dp, vertical = 2.dp)
            ) {
                Text("$alertCount", fontSize = 10.sp, fontWeight = FontWeight.Black, color = badgeOnColor)
            }
        } else if (isSubscribed) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(end = 4.dp)
                    .size(18.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Notifications, null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(9.dp))
            }
        }
    }
}

// ─── Subscribe Sheet ─────────────────────────────────────────────────────
@Composable
private fun SubscribeLineSheet(
    allLines: List<TransportLine>,
    subscriptions: Map<String, LineSubscription>,
    onToggle: (TransportLine) -> Unit,
    onClose: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    val sortedLines = remember(allLines) {
        allLines.sortedWith(
            compareBy<TransportLine> { it.mode.sortOrder }.thenComparator { a, b ->
                val (ap, an) = naturalLineOrder(a.displayName)
                val (bp, bn) = naturalLineOrder(b.displayName)
                ap.compareTo(bp).takeIf { it != 0 } ?: an.compareTo(bn)
            }
        )
    }
    val filtered = remember(sortedLines, query) {
        if (query.isBlank()) sortedLines else sortedLines.filter { it.displayName.contains(query, ignoreCase = true) }
    }
    Column(modifier = Modifier.fillMaxWidth().navigationBarsPadding()) {
        SheetHeader(
            title = "S'abonner à une ligne",
            subtitle = "Touchez une ligne pour recevoir ses alertes ; touchez-la de nouveau pour arrêter.",
            onClose = onClose
        )
        Column(modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 16.dp)) {
        OutlinedTextField(
            value = query, onValueChange = { query = it },
            placeholder = { Text("Rechercher", fontSize = 13.sp) },
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        LazyVerticalGrid(
            columns = GridCells.Fixed(4),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth().heightIn(min = 200.dp, max = 460.dp)
        ) {
            items(filtered, key = { it.id }) { line ->
                val subscribed = LineSubscriptions.isSubscribed(subscriptions, line)
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (subscribed) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant)
                        .clickable { onToggle(line) }
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        LineBadge(line.displayName, size = 32.dp, fontSize = 11.sp)
                        if (subscribed) {
                            Icon(Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(12.dp))
                        }
                    }
                }
            }
        }
        }
    }
}

// ─── Line Detail Sheet ───────────────────────────────────────────────────
@Composable
private fun LineDetailSheet(
    line: TransportLine,
    alerts: List<TCLAlert>,
    isSubscribed: Boolean,
    onOptions: () -> Unit,
    onUnsubscribe: () -> Unit,
    onClose: () -> Unit
) {
    val modeColor = Tokens.mode(line.mode)
    val now = remember { System.currentTimeMillis() / 1000L }
    val ongoingAlerts = remember(alerts) {
        alerts.filter { it.isOngoing(now) }.sortedBy { it.severity.sortOrder }
    }
    val upcomingAlerts = remember(alerts) {
        alerts.filter { it.isUpcoming(now) }.sortedBy { it.debutEpoch ?: Long.MAX_VALUE }
    }

    Column(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp).navigationBarsPadding()) {
        SheetHeader(
            title = "Ligne ${line.displayName}",
            subtitle = line.mode.displayName,
            onClose = onClose,
            leading = { LineBadge(line.displayName, size = 48.dp) }
        )
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        // Abonnement : même disposition que sur iOS (abonné + options + désabonnement, ou bouton principal)
        if (isSubscribed) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.10f))
                        .padding(horizontal = 14.dp, vertical = 9.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp)
                ) {
                    Icon(Icons.Filled.Notifications, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(15.dp))
                    Text("Abonné", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.weight(1f))
                FilledTonalButton(onClick = onOptions, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)) {
                    Icon(Icons.Filled.Tune, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(5.dp))
                    Text("Options", fontWeight = FontWeight.SemiBold)
                }
                OutlinedButton(
                    onClick = onUnsubscribe,
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Tokens.error)
                ) {
                    Icon(Icons.Filled.NotificationsOff, contentDescription = "Se désabonner", modifier = Modifier.size(16.dp))
                }
            }
        } else {
            Button(onClick = onOptions, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.NotificationAdd, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("S'abonner à cette ligne", fontWeight = FontWeight.SemiBold)
            }
        }
        Spacer(Modifier.height(16.dp))
        if (ongoingAlerts.isEmpty() && upcomingAlerts.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.Filled.CheckCircle, null, tint = Tokens.success, modifier = Modifier.size(48.dp))
                    Text("Service normal", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                    Text("Aucune perturbation en cours sur cette ligne", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            if (ongoingAlerts.isNotEmpty()) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Filled.Warning, null, tint = Tokens.warning, modifier = Modifier.size(14.dp))
                    Text("En cours", fontSize = 13.sp, color = Tokens.warning, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.height(8.dp))
                ongoingAlerts.forEach { alert ->
                    AlertDetailRow(alert, now = now)
                    Spacer(Modifier.height(8.dp))
                }
            }
            if (upcomingAlerts.isNotEmpty()) {
                if (ongoingAlerts.isNotEmpty()) Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Filled.Notifications, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(14.dp))
                    Text("À venir", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.height(8.dp))
                upcomingAlerts.forEach { alert ->
                    AlertDetailRow(alert, now = now, isUpcoming = true)
                    Spacer(Modifier.height(8.dp))
                }
            }
        }
        Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun AlertDetailRow(alert: TCLAlert, now: Long, isUpcoming: Boolean = false) {
    var expanded by remember { mutableStateOf(false) }
    val color = if (isUpcoming) MaterialTheme.colorScheme.onSurfaceVariant else Tokens.severity(alert.severity)
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = color.copy(alpha = 0.08f),
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable { expanded = !expanded }
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            Box(modifier = Modifier.width(4.dp).fillMaxHeight().background(color))
            Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(
                        if (isUpcoming) Icons.Filled.Schedule else Icons.Filled.Warning,
                        null, tint = color, modifier = Modifier.size(13.dp)
                    )
                    Text(
                        if (isUpcoming) "À venir" else alert.severity.displayName,
                        style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = color
                    )
                    if (alert.cause.isNotBlank()) {
                        Text("·", color = MaterialTheme.colorScheme.outline)
                        Text(
                            alert.cause, style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false)
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    alert.debutEpoch?.let { debut ->
                        Text(
                            AlertDates.startLabel(debut, now), style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.outline
                        )
                    }
                }
                Text(alert.titre, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                if (expanded) {
                    if (alert.message.isNotBlank()) {
                        Text(alert.message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    alert.finEpoch?.let { fin ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            Icon(Icons.Filled.Schedule, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(12.dp))
                            Text(AlertDates.endLabel(fin, now), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                } else if (alert.message.isNotBlank()) {
                    Text("Touchez pour lire le détail", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
                }
            }
        }
    }
}

// ─── Options de notification d'une ligne (parité iOS SubscriptionOptionsSheet) ───────
@Composable
private fun SubscriptionOptionsSheet(
    line: TransportLine,
    initialTypes: Set<AlertSeverity>,
    onSave: (Set<AlertSeverity>) -> Unit,
    onCancel: () -> Unit
) {
    var selected by remember(line) { mutableStateOf(initialTypes) }
    Column(modifier = Modifier.fillMaxWidth().navigationBarsPadding()) {
        SheetHeader(title = "Options de notification", onClose = onCancel)
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            LineBadge(line.displayName, size = 72.dp)
            Text(
                "Notifications pour la ligne ${line.displayName}",
                style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 8.dp)
            )
            Text(
                "Choisissez les types d'alertes que vous souhaitez recevoir",
                style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
        Spacer(Modifier.height(20.dp))
        Column(modifier = Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            AlertSeverity.entries.forEach { severity ->
                val isSelected = severity in selected
                val color = Tokens.severity(severity)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .clickable { selected = if (isSelected) selected - severity else selected + severity }
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier.size(44.dp).clip(CircleShape).background(color.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            when (severity) {
                                AlertSeverity.MAJOR -> Icons.Filled.Warning
                                AlertSeverity.DISRUPTION -> Icons.Filled.NotificationsActive
                                AlertSeverity.INFO -> Icons.Filled.Info
                            },
                            null, tint = color, modifier = Modifier.size(20.dp)
                        )
                    }
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(severity.displayName, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
                        Text(severity.description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Icon(
                        if (isSelected) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                        null, tint = if (isSelected) color else MaterialTheme.colorScheme.outline, modifier = Modifier.size(26.dp)
                    )
                }
            }
        }
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = { onSave(selected) },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            colors = if (selected.isEmpty()) ButtonDefaults.buttonColors(containerColor = Tokens.error) else ButtonDefaults.buttonColors()
        ) {
            Text(if (selected.isEmpty()) "Se désabonner" else "Enregistrer", fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(vertical = 4.dp))
        }
        TextButton(onClick = onCancel, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)) {
            Text("Annuler")
        }
        Spacer(Modifier.height(8.dp))
    }
}

// ─── Helpers (ré-utilisables ailleurs) ───────────────────────────────────
internal fun transportModeOnColor(mode: TransportMode): Color = when (mode) {
    TransportMode.METRO   -> Tokens.onLight
    TransportMode.NAVIGONE -> Tokens.onLight
    else                  -> Color.White
}

internal fun transportModeIcon(mode: TransportMode): ImageVector = when (mode) {
    TransportMode.METRO     -> Icons.Filled.Train
    TransportMode.TRAMWAY   -> Icons.Filled.Tram
    TransportMode.FUNICULAR -> Icons.Filled.Train
    TransportMode.BUS_C     -> Icons.Filled.DirectionsBus
    TransportMode.BUS       -> Icons.Filled.DirectionsBus
    TransportMode.NAVIGONE  -> Icons.Filled.DirectionsBoat
}
