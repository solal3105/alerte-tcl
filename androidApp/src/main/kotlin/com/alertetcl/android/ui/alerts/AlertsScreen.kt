package com.alertetcl.android.ui.alerts

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.runtime.produceState
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.BusLine
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransitLine
import com.alertetcl.shared.models.TransportLine
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.services.BusLineService
import com.alertetcl.shared.services.TransitLineService
import com.alertetcl.shared.viewmodels.AlertsViewModel
import kotlinx.coroutines.launch

// Couleurs iOS — alignées sur les system colors
private val iOSRed    = Color(0xFFFF3B30)
private val iOSOrange = Color(0xFFFF9500)
private val iOSGreen  = Color(0xFF34C759)
private val iOSBlue   = Color(0xFF007AFF)
private val secondary = Color(0xFF8E8E93)
private val groupedBg = Color(0xFFF2F2F7)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlertsScreen() {
    val viewModel = remember { AlertsViewModel() }
    DisposableEffect(Unit) {
        viewModel.startPolling()
        onDispose { viewModel.dispose() }
    }
    val alerts by viewModel.alerts.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.errorMessage.collectAsState()

    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val scope = rememberCoroutineScope()
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())

    val transitLines = produceState<List<TransitLine>>(initialValue = emptyList()) {
        value = runCatching { TransitLineService.shared.fetchTransitLines() }.getOrDefault(emptyList())
    }
    val busLines = produceState<List<BusLine>>(initialValue = emptyList()) {
        value = runCatching { BusLineService.shared.fetchBusLines() }.getOrDefault(emptyList())
    }
    val allLines: List<TransportLine> = remember(transitLines.value, busLines.value) {
        val tl = transitLines.value.map {
            TransportLine.create(it.name, it.name, TransportMode.detectFromLine(it.name))
        }
        val bl = busLines.value.map {
            TransportLine.create(it.name, it.name, TransportMode.detectFromLine(it.name))
        }
        (tl + bl).distinctBy { it.ligneCom }
    }

    val subscribedLines = remember(allLines, favorites) {
        allLines.filter { it.ligneCom in favorites }
    }
    val alertsByLine = remember(alerts) { alerts.groupBy { it.ligneCom } }

    var selectedModeFilter by remember { mutableStateOf<TransportMode?>(null) }
    var subscribeSheetOpen by remember { mutableStateOf(false) }
    var selectedLine by remember { mutableStateOf<TransportLine?>(null) }
    var refreshing by remember { mutableStateOf(false) }

    PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = {
            refreshing = true
            viewModel.refresh()
        },
        modifier = Modifier.fillMaxSize().background(groupedBg)
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
                    Text("Erreur : $error")
                }
            }
            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 40.dp)
                ) {
                    if (subscribedLines.isNotEmpty()) {
                        item {
                            StatusSummaryBanner(
                                subscribedLines = subscribedLines,
                                alertsByLine = alertsByLine,
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
                                .background(Color(0xFFC6C6C8).copy(alpha = 0.5f))
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
                            favorites = favorites,
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
            sheetState = rememberModalBottomSheetState()
        ) {
            SubscribeLineSheet(
                allLines = allLines,
                favorites = favorites,
                onToggle = { line -> scope.launch { store.toggleFavoriteLine(line.ligneCom) } }
            )
        }
    }

    selectedLine?.let { line ->
        ModalBottomSheet(
            onDismissRequest = { selectedLine = null },
            sheetState = rememberModalBottomSheetState()
        ) {
            LineDetailSheet(
                line = line,
                alerts = alertsByLine[line.ligneCom].orEmpty(),
                isSubscribed = line.ligneCom in favorites,
                onToggleSubscription = { scope.launch { store.toggleFavoriteLine(line.ligneCom) } }
            )
        }
    }
}

// ─── Status Summary Banner ───────────────────────────────────────────────
@Composable
private fun StatusSummaryBanner(
    subscribedLines: List<TransportLine>,
    alertsByLine: Map<String, List<TCLAlert>>,
    modifier: Modifier = Modifier
) {
    val totalAlerts = subscribedLines.sumOf { alertsByLine[it.ligneCom]?.size ?: 0 }
    val hasMajor = subscribedLines.any { line ->
        alertsByLine[line.ligneCom]?.any { it.severity == AlertSeverity.MAJOR } == true
    }
    val color = when { hasMajor -> iOSRed; totalAlerts > 0 -> iOSOrange; else -> iOSGreen }
    val icon: ImageVector = when {
        hasMajor -> Icons.Filled.Warning
        totalAlerts > 0 -> Icons.Filled.NotificationsActive
        else -> Icons.Filled.CheckCircle
    }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(color.copy(alpha = 0.10f))
            .border(1.dp, color.copy(alpha = 0.25f), RoundedCornerShape(16.dp))
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(
                modifier = Modifier.size(38.dp).clip(CircleShape).background(color),
                contentAlignment = Alignment.Center
            ) { Icon(icon, null, tint = Color.White, modifier = Modifier.size(16.dp)) }

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                if (totalAlerts == 0) {
                    Text("Toutes vos lignes sont normales", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                } else {
                    Text(
                        "$totalAlerts perturbation${if (totalAlerts > 1) "s" else ""} sur vos lignes",
                        fontSize = 14.sp, fontWeight = FontWeight.SemiBold
                    )
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
            }.thenBy { it.mode.sortOrder }.thenBy { it.displayName }
        )
    }

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("Mes lignes", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                if (subscribedLines.isNotEmpty()) {
                    Text(
                        "${subscribedLines.size} abonnement${if (subscribedLines.size > 1) "s" else ""}",
                        fontSize = 12.sp, color = secondary
                    )
                }
            }
            IconButton(
                onClick = onAdd,
                modifier = Modifier.size(30.dp),
                colors = IconButtonDefaults.iconButtonColors(containerColor = iOSBlue, contentColor = Color.White)
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
                                .background(if (isCurrent) iOSBlue else Color(0xFFC6C6C8))
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
                modifier = Modifier.size(72.dp).clip(CircleShape).background(iOSBlue.copy(alpha = 0.10f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.NotificationAdd, null, tint = iOSBlue, modifier = Modifier.size(30.dp))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Suivez vos lignes", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    "Recevez des alertes en temps réel pour les lignes qui vous importent",
                    fontSize = 13.sp, color = secondary, textAlign = TextAlign.Center
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.Add, null, tint = iOSBlue, modifier = Modifier.size(16.dp))
                Text("S'abonner à une ligne", fontSize = 13.sp, color = iOSBlue, fontWeight = FontWeight.SemiBold)
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
        AlertSeverity.MAJOR -> iOSRed
        AlertSeverity.DISRUPTION -> iOSOrange
        AlertSeverity.INFO -> iOSBlue
        null -> iOSGreen
    }
    val modeColor = transportModeColor(line.mode)

    Surface(
        shape = RoundedCornerShape(20.dp),
        color = Color.White,
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
                LineBadge(line.ligneCom, size = 62.dp, fontSize = 20.sp)
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(modeColor.copy(alpha = 0.12f))
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    ) {
                        Text(line.mode.displayName, fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold, color = modeColor)
                    }
                    Text("Ligne ${line.displayName}", fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(modifier = Modifier.size(7.dp).clip(CircleShape).background(statusColor))
                        if (alerts.isEmpty()) {
                            Text("Service normal", fontSize = 13.sp, color = secondary)
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
                        Text("${alerts.size}", fontSize = 28.sp, fontWeight = FontWeight.Black, color = statusColor)
                        Text(if (alerts.size > 1) "alertes" else "alerte",
                            fontSize = 10.sp, fontWeight = FontWeight.Bold, color = statusColor.copy(alpha = 0.65f))
                    }
                } else {
                    Icon(Icons.Filled.CheckCircle, null, tint = iOSGreen, modifier = Modifier.size(28.dp))
                }
            }
        }
    }
}

// ─── All Lines section ───────────────────────────────────────────────────
@Composable
private fun AllLinesHeader(modifier: Modifier = Modifier) {
    Row(modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        Text("Toutes les lignes", fontSize = 22.sp, fontWeight = FontWeight.Bold)
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
        ModeChip(label = "Tout", icon = Icons.Filled.Apps, color = secondary,
            badgeCount = totalAlerts,
            isSelected = selected == null) { onSelect(null) }
        availableModes.forEach { mode ->
            ModeChip(
                label = mode.displayName,
                icon = transportModeIcon(mode),
                color = transportModeColor(mode),
                badgeCount = countByMode[mode] ?: 0,
                isSelected = selected == mode
            ) { onSelect(mode) }
        }
    }
}

@Composable
private fun ModeChip(label: String, icon: ImageVector, color: Color, badgeCount: Int = 0, isSelected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (isSelected) color else color.copy(alpha = 0.12f))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 7.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon(icon, null, tint = if (isSelected) Color.White else color, modifier = Modifier.size(11.dp))
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                color = if (isSelected) Color.White else color)
            if (badgeCount > 0) {
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (isSelected) Color.White else color)
                        .padding(horizontal = 6.dp, vertical = 1.dp)
                ) {
                    Text("$badgeCount", fontSize = 10.sp, fontWeight = FontWeight.Bold,
                        color = if (isSelected) color else Color.White)
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
    favorites: Set<String>,
    onClick: (TransportLine) -> Unit,
    modifier: Modifier = Modifier
) {
    val filtered = remember(lines, selectedMode) {
        val base = if (selectedMode != null) lines.filter { it.mode == selectedMode } else lines
        base.sortedWith(compareBy<TransportLine> { it.mode.sortOrder }.thenBy { it.displayName })
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
                isSubscribed = line.ligneCom in favorites,
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
    val modeColor = transportModeColor(line.mode)
    val badgeColor = when (highestSeverity) {
        AlertSeverity.MAJOR -> iOSRed
        AlertSeverity.DISRUPTION -> iOSOrange
        AlertSeverity.INFO -> iOSBlue
        null -> iOSRed
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(96.dp)
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
            LineBadge(line.ligneCom, size = 50.dp, fontSize = 16.sp)
            Text(line.displayName, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
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
                Text("$alertCount", fontSize = 10.sp, fontWeight = FontWeight.Black, color = Color.White)
            }
        } else if (isSubscribed) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(end = 4.dp)
                    .size(18.dp)
                    .clip(CircleShape)
                    .background(iOSBlue),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Notifications, null, tint = Color.White, modifier = Modifier.size(9.dp))
            }
        }
    }
}

// ─── Subscribe Sheet ─────────────────────────────────────────────────────
@Composable
private fun SubscribeLineSheet(
    allLines: List<TransportLine>,
    favorites: Set<String>,
    onToggle: (TransportLine) -> Unit
) {
    var query by remember { mutableStateOf("") }
    val sortedLines = remember(allLines) {
        allLines.sortedWith(compareBy<TransportLine> { it.mode.sortOrder }.thenBy { it.displayName })
    }
    val filtered = remember(sortedLines, query) {
        if (query.isBlank()) sortedLines else sortedLines.filter { it.displayName.contains(query, ignoreCase = true) }
    }
    Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Text("S'abonner à une ligne", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(12.dp))
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
            modifier = Modifier.fillMaxWidth().height(360.dp)
        ) {
            items(filtered, key = { it.id }) { line ->
                val subscribed = line.ligneCom in favorites
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (subscribed) iOSBlue.copy(alpha = 0.18f) else groupedBg)
                        .clickable { onToggle(line) }
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        LineBadge(line.ligneCom, size = 32.dp, fontSize = 11.sp)
                        if (subscribed) {
                            Icon(Icons.Filled.CheckCircle, null, tint = iOSBlue, modifier = Modifier.size(12.dp))
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
    onToggleSubscription: () -> Unit
) {
    val modeColor = transportModeColor(line.mode)
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            LineBadge(line.ligneCom, size = 56.dp, fontSize = 18.sp)
            Column(modifier = Modifier.weight(1f)) {
                Text("Ligne ${line.displayName}", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text(line.mode.displayName, fontSize = 13.sp, color = modeColor, fontWeight = FontWeight.SemiBold)
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (isSubscribed) iOSBlue else groupedBg)
                    .clickable { onToggleSubscription() }
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Filled.Notifications, null,
                        tint = if (isSubscribed) Color.White else iOSBlue, modifier = Modifier.size(14.dp))
                    Text(if (isSubscribed) "Abonné" else "S'abonner",
                        fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        color = if (isSubscribed) Color.White else iOSBlue)
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        if (alerts.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.Filled.CheckCircle, null, tint = iOSGreen, modifier = Modifier.size(48.dp))
                    Text("Aucune perturbation", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Text("Le service circule normalement", fontSize = 13.sp, color = secondary)
                }
            }
        } else {
            Text("Perturbations en cours", fontSize = 13.sp, color = secondary, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            alerts.sortedBy { it.severity.sortOrder }.forEach { alert ->
                AlertDetailRow(alert)
                Spacer(Modifier.height(8.dp))
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun AlertDetailRow(alert: TCLAlert) {
    val color = when (alert.severity) {
        AlertSeverity.MAJOR -> iOSRed
        AlertSeverity.DISRUPTION -> iOSOrange
        AlertSeverity.INFO -> iOSBlue
    }
    Surface(shape = RoundedCornerShape(14.dp), color = color.copy(alpha = 0.08f),
        modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(color))
                Text(alert.severity.displayName, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = color)
            }
            Spacer(Modifier.height(4.dp))
            Text(alert.titre, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            if (alert.message.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(alert.message, fontSize = 12.sp, color = Color.DarkGray)
            }
        }
    }
}

// ─── Helpers (ré-utilisables ailleurs) ───────────────────────────────────
@Composable
internal fun LineBadge(line: String, size: Dp, fontSize: TextUnit = 14.sp) {
    val bg = colorFromHex(LineColors.backgroundHex(line))
    val tx = colorFromHex(LineColors.textHex(line))
    Box(
        modifier = Modifier.size(size).clip(RoundedCornerShape(10.dp)).background(bg),
        contentAlignment = Alignment.Center
    ) { Text(line, color = tx, fontSize = fontSize, fontWeight = FontWeight.Black, maxLines = 1) }
}

internal fun transportModeColor(mode: TransportMode): Color = when (mode) {
    TransportMode.METRO     -> Color(0xFFE63946)
    TransportMode.TRAMWAY   -> Color(0xFF1E88E5)
    TransportMode.FUNICULAR -> Color(0xFF8E44AD)
    TransportMode.BUS_C     -> Color(0xFFE67E22)
    TransportMode.BUS       -> Color(0xFF455A64)
    TransportMode.NAVETTE   -> Color(0xFF16A085)
}

internal fun transportModeIcon(mode: TransportMode): ImageVector = when (mode) {
    TransportMode.METRO     -> Icons.Filled.Train
    TransportMode.TRAMWAY   -> Icons.Filled.Tram
    TransportMode.FUNICULAR -> Icons.Filled.Train
    TransportMode.BUS_C     -> Icons.Filled.DirectionsBus
    TransportMode.BUS       -> Icons.Filled.DirectionsBus
    TransportMode.NAVETTE   -> Icons.Filled.DirectionsBoat
}
