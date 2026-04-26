package com.alertetcl.android.ui.lines

import androidx.compose.foundation.background
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.ui.alerts.transportModeColor
import com.alertetcl.android.ui.alerts.transportModeIcon
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransportMode
import kotlinx.coroutines.launch

private val secondary = Color(0xFF8E8E93)
private val groupedBg = Color(0xFFF2F2F7)

/**
 * Vue liste des lignes équivalente à `LinesListView.swift` (iOS) :
 * - mode-filter pills (capsules) en haut, scrollable horizontalement
 * - sections groupées par mode de transport (header + grille 2 colonnes)
 * - LineCard avec gros numéro de ligne (28sp Black) + cloche d'abonnement
 */
@Composable
fun LinesListScreen(
    allLineCodes: List<Pair<String, TransportMode>>,
    alerts: List<TCLAlert>
) {
    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val scope = rememberCoroutineScope()
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())

    var selectedMode by remember { mutableStateOf<TransportMode?>(null) }

    val alertCountByLine = remember(alerts) { alerts.groupingBy { it.ligneCom }.eachCount() }

    val grouped: Map<TransportMode, List<Pair<String, TransportMode>>> = remember(allLineCodes, selectedMode) {
        val base = if (selectedMode != null) allLineCodes.filter { it.second == selectedMode } else allLineCodes
        base.distinctBy { it.first }
            .groupBy { it.second }
            .toSortedMap(compareBy { it.sortOrder })
            .mapValues { (_, list) -> list.sortedBy { it.first } }
    }

    Column(modifier = Modifier.fillMaxSize().background(groupedBg)) {
        // Mode filter pills horizontal
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ModeFilterPill(
                title = "Tous", icon = Icons.Filled.List,
                isSelected = selectedMode == null
            ) { selectedMode = null }
            TransportMode.entries.sortedBy { it.sortOrder }.forEach { mode ->
                ModeFilterPill(
                    title = mode.displayName, icon = transportModeIcon(mode),
                    isSelected = selectedMode == mode
                ) { selectedMode = mode }
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            grouped.forEach { (mode, lines) ->
                if (lines.isNotEmpty()) {
                    item(key = "section_${mode.name}") {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(
                                modifier = Modifier.padding(horizontal = 16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(
                                    transportModeIcon(mode), null,
                                    tint = transportModeColor(mode),
                                    modifier = Modifier.size(14.dp)
                                )
                                Text(
                                    mode.displayName.uppercase(),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Black,
                                    letterSpacing = 0.5.sp
                                )
                            }
                            // Grille 2 colonnes inline (hauteur calculée)
                            val rows = (lines.size + 1) / 2
                            val cellH = 100.dp
                            val totalH = (cellH + 12.dp) * rows
                            LazyVerticalGrid(
                                columns = GridCells.Fixed(2),
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(totalH)
                                    .padding(horizontal = 16.dp),
                                userScrollEnabled = false
                            ) {
                                items(lines, key = { it.first }) { (code, _) ->
                                    LineCard(
                                        line = code,
                                        alertCount = alertCountByLine[code] ?: 0,
                                        isSubscribed = code in favorites,
                                        onClick = { scope.launch { store.toggleFavoriteLine(code) } }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ModeFilterPill(title: String, icon: ImageVector, isSelected: Boolean, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(50),
        color = if (isSelected) Color.Black else Color(0xFFE5E5EA),
        shadowElevation = 2.dp,
        modifier = Modifier.clickable { onClick() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(icon, null,
                tint = if (isSelected) Color.White else Color.Black, modifier = Modifier.size(12.dp))
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = if (isSelected) Color.White else Color.Black)
        }
    }
}

@Composable
private fun LineCard(line: String, alertCount: Int, isSubscribed: Boolean, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        modifier = Modifier
            .fillMaxWidth()
            .height(100.dp)
            .shadow(4.dp, RoundedCornerShape(16.dp))
            .clickable { onClick() }
    ) {
        Box(modifier = Modifier.fillMaxSize().padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top
            ) {
                Text(
                    line,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Black,
                    color = Color.Black,
                    maxLines = 1,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    if (isSubscribed) Icons.Filled.Notifications else Icons.Outlined.Notifications,
                    null,
                    tint = Color.Black,
                    modifier = Modifier.size(16.dp)
                )
            }
            Row(modifier = Modifier.align(Alignment.BottomStart)) {
                if (alertCount > 0) {
                    Text(
                        "$alertCount alerte${if (alertCount > 1) "s" else ""}",
                        fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.Black
                    )
                } else {
                    Text("RAS", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = secondary)
                }
            }
        }
    }
}
