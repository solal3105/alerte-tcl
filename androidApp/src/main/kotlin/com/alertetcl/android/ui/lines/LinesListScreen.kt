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
import androidx.compose.foundation.layout.aspectRatio
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.models.LineColors
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.models.TransportMode
import kotlinx.coroutines.launch

@Composable
fun LinesListScreen(
    allLineCodes: List<Pair<String, TransportMode>>,
    alerts: List<TCLAlert>
) {
    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val scope = rememberCoroutineScope()
    val favorites by store.favoriteLines.collectAsState(initial = emptySet())

    var query by remember { mutableStateOf("") }
    var selectedMode by remember { mutableStateOf<TransportMode?>(null) }

    val alertCountByLine = remember(alerts) {
        alerts.groupingBy { it.ligneCom }.eachCount()
    }

    val filtered = remember(allLineCodes, query, selectedMode) {
        allLineCodes
            .filter { selectedMode == null || it.second == selectedMode }
            .filter { query.isBlank() || it.first.contains(query, ignoreCase = true) }
            .distinctBy { it.first }
            .sortedWith(
                compareBy<Pair<String, TransportMode>> { it.second.sortOrder }
                    .thenBy { it.first }
            )
    }

    Column(modifier = Modifier.fillMaxSize().background(Color(0xFFF2F2F7))) {
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            placeholder = { Text("Rechercher une ligne", fontSize = 13.sp) },
            singleLine = true
        )
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = selectedMode == null,
                onClick = { selectedMode = null },
                label = { Text("Tous", fontSize = 12.sp) }
            )
            TransportMode.entries.sortedBy { it.sortOrder }.forEach { m ->
                FilterChip(
                    selected = selectedMode == m,
                    onClick = { selectedMode = m },
                    label = { Text(m.displayName, fontSize = 12.sp) }
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            items(filtered, key = { it.first }) { (code, _) ->
                LineCard(
                    line = code,
                    alertCount = alertCountByLine[code] ?: 0,
                    isFavorite = code in favorites,
                    onClick = { scope.launch { store.toggleFavoriteLine(code) } }
                )
            }
        }
    }
}

@Composable
private fun LineCard(line: String, alertCount: Int, isFavorite: Boolean, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = colorFromHex(LineColors.backgroundHex(line)),
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1.4f)
            .clickable { onClick() }
    ) {
        Box(modifier = Modifier.fillMaxSize().padding(14.dp)) {
            Text(
                line,
                color = colorFromHex(LineColors.textHex(line)),
                fontSize = 24.sp,
                fontWeight = FontWeight.Black
            )
            Icon(
                if (isFavorite) Icons.Filled.Notifications else Icons.Outlined.Notifications,
                contentDescription = null,
                tint = colorFromHex(LineColors.textHex(line)),
                modifier = Modifier.align(Alignment.TopEnd).size(18.dp)
            )
            Text(
                if (alertCount > 0) "$alertCount alerte" + if (alertCount > 1) "s" else "" else "RAS",
                color = colorFromHex(LineColors.textHex(line)).copy(alpha = if (alertCount > 0) 1f else 0.7f),
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.BottomStart)
            )
        }
    }
}
