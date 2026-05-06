package com.alertetcl.android.ui.widgetstop

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.ui.alerts.LineBadge
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.services.TransitStopService
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WidgetStopSelectionScreen() {
    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val scope = rememberCoroutineScope()
    val widgetStops by store.widgetStops.collectAsState(initial = emptyList())

    val allStops = produceState<List<TransitStop>>(initialValue = emptyList()) {
        value = runCatching { TransitStopService.shared.fetchStops() }.getOrDefault(emptyList())
    }

    var query by remember { mutableStateOf("") }
    var showAddSheet by remember { mutableStateOf<TransitStop?>(null) }

    val filtered = remember(allStops.value, query) {
        val q = query.trim()
        if (q.isEmpty()) emptyList()
        else allStops.value.asSequence()
            .filter { it.nom.contains(q, ignoreCase = true) || it.commune.contains(q, ignoreCase = true) }
            .take(40)
            .toList()
    }
    val selectedStops = remember(allStops.value, widgetStops) {
        allStops.value.filter { it.id in widgetStops }
    }

    Column(modifier = Modifier.fillMaxSize().background(Color(0xFFF2F2F7))) {
        Text(
            "Arrêts du widget",
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp),
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            placeholder = { Text("Rechercher un arrêt", fontSize = 13.sp) },
            singleLine = true
        )
        Spacer(Modifier.height(8.dp))
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            if (selectedStops.isNotEmpty()) {
                item {
                    Text(
                        "Arrêts ajoutés (${selectedStops.size})",
                        fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF8E8E93),
                        modifier = Modifier.padding(start = 6.dp, top = 4.dp, bottom = 4.dp)
                    )
                }
                items(selectedStops, key = { "sel_${it.id}" }) { stop ->
                    WidgetStopRow(
                        stop = stop, isSelected = true,
                        onTap = { showAddSheet = stop },
                        onRemove = { scope.launch { store.removeWidgetStop(stop.id) } }
                    )
                }
                item {
                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = Color(0xFFE5E5EA))
                }
            }
            if (filtered.isNotEmpty()) {
                item {
                    Text(
                        "Résultats (${filtered.size})",
                        fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF8E8E93),
                        modifier = Modifier.padding(start = 6.dp, top = 4.dp, bottom = 4.dp)
                    )
                }
                items(filtered, key = { "search_${it.id}" }) { stop ->
                    WidgetStopRow(
                        stop = stop, isSelected = stop.id in widgetStops,
                        onTap = { showAddSheet = stop }, onRemove = null
                    )
                }
            } else if (query.isNotBlank()) {
                item {
                    Text(
                        "Aucun arrêt trouvé", fontSize = 13.sp, color = Color(0xFF8E8E93),
                        modifier = Modifier.padding(16.dp)
                    )
                }
            }
        }
    }

    showAddSheet?.let { stop ->
        ModalBottomSheet(
            onDismissRequest = { showAddSheet = null },
            sheetState = rememberModalBottomSheetState()
        ) {
            AddToWidgetSheet(
                stop = stop,
                isAlreadySaved = stop.id in widgetStops,
                onAdd = {
                    scope.launch { store.addWidgetStop(stop.id) }
                },
                onDismiss = { showAddSheet = null }
            )
        }
    }
}

@Composable
private fun WidgetStopRow(
    stop: TransitStop,
    isSelected: Boolean,
    onTap: () -> Unit,
    onRemove: (() -> Unit)?
) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        tonalElevation = 1.dp,
        modifier = Modifier.fillMaxWidth().clickable { onTap() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier.size(36.dp).clip(CircleShape)
                    .background(if (isSelected) Color(0xFF34C759).copy(alpha = 0.15f) else Color(0xFF007AFF).copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Place, null,
                    tint = if (isSelected) Color(0xFF34C759) else Color(0xFF007AFF),
                    modifier = Modifier.size(18.dp)
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(stop.nom, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Text(stop.commune, fontSize = 11.sp, color = Color(0xFF8E8E93))
                if (stop.lines.isNotEmpty()) {
                    Spacer(Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        stop.lines.take(5).forEach { line ->
                            LineBadge(line, size = 22.dp, fontSize = 10.sp)
                        }
                        if (stop.lines.size > 5) {
                            Text(
                                "+${stop.lines.size - 5}", fontSize = 10.sp, color = Color(0xFF8E8E93),
                                modifier = Modifier.padding(start = 4.dp, top = 4.dp)
                            )
                        }
                    }
                }
            }
            if (isSelected && onRemove != null) {
                IconButton(onClick = onRemove) {
                    Icon(Icons.Filled.Delete, "Retirer", tint = Color(0xFFFF3B30), modifier = Modifier.size(18.dp))
                }
            } else {
                Icon(
                    Icons.Filled.AddCircle, "Ajouter",
                    tint = Color(0xFF007AFF), modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

// ─── Add-to-widget sheet (iOS parity) ────────────────────────────────────

@Composable
private fun AddToWidgetSheet(
    stop: TransitStop,
    isAlreadySaved: Boolean,
    onAdd: () -> Unit,
    onDismiss: () -> Unit
) {
    var selectedLineDirection by remember { mutableStateOf<Pair<String, String>?>(null) }
    var showConfirmation by remember { mutableStateOf(isAlreadySaved) }

    val lineDirections = remember(stop) {
        val items = stop.desserte.split(",").mapNotNull {
            val parts = it.split(":")
            if (parts.size >= 2) parts[0].trim() to parts[1].trim() else null
        }
        items.distinctBy { it.first to it.second }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxWidth().background(Color(0xFFF2F2F7))
        ) {
            // Header section
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Box(
                    modifier = Modifier.size(70.dp).clip(CircleShape)
                        .background(Brush.linearGradient(listOf(Color(0xFF007AFF), Color(0xFF0051D5)))),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Filled.Add, null, tint = Color.White, modifier = Modifier.size(32.dp))
                }
                Text(stop.nom, fontWeight = FontWeight.Bold, fontSize = 18.sp,
                    textAlign = TextAlign.Center)
                Text(
                    "Choisissez la ligne et la direction à afficher dans votre widget",
                    fontSize = 13.sp, color = Color(0xFF8E8E93),
                    textAlign = TextAlign.Center
                )
            }

            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(lineDirections, key = { "${it.first}_${it.second}" }) { (line, direction) ->
                    val isSel = selectedLineDirection?.first == line && selectedLineDirection?.second == direction
                    LineDirectionRow(
                        line = line, direction = direction,
                        isSelected = isSel, isAlreadySaved = isAlreadySaved,
                        onClick = { selectedLineDirection = line to direction }
                    )
                }
            }

            if (selectedLineDirection != null) {
                Button(
                    onClick = {
                        onAdd()
                        showConfirmation = true
                    },
                    modifier = Modifier.fillMaxWidth().padding(20.dp).height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF007AFF)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Filled.AddCircle, null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.size(8.dp))
                    Text("Ajouter au widget", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        if (showConfirmation) {
            ConfirmationOverlay(onDismiss = onDismiss)
        }
    }
}

@Composable
private fun LineDirectionRow(
    line: String, direction: String,
    isSelected: Boolean, isAlreadySaved: Boolean, onClick: () -> Unit
) {
    val borderColor = when {
        isAlreadySaved -> Color(0xFF34C759)
        isSelected     -> Color(0xFF007AFF)
        else           -> Color.Transparent
    }
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !isAlreadySaved) { onClick() }
    ) {
        Row(
            modifier = Modifier
                .padding(14.dp)
                .background(borderColor.copy(alpha = 0.0f)),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            LineBadge(line, size = 36.dp, fontSize = 14.sp)
            Column(modifier = Modifier.weight(1f)) {
                Text("Direction", fontSize = 10.sp, color = Color(0xFF8E8E93))
                Text(direction, fontSize = 14.sp, fontWeight = FontWeight.Medium, maxLines = 2)
            }
            when {
                isAlreadySaved -> Icon(Icons.Filled.CheckCircle, null,
                    tint = Color(0xFF34C759), modifier = Modifier.size(22.dp))
                isSelected     -> Icon(Icons.Filled.CheckCircle, null,
                    tint = Color(0xFF007AFF), modifier = Modifier.size(22.dp))
                else           -> Icon(Icons.Filled.Add, null,
                    tint = Color(0xFFC7C7CC), modifier = Modifier.size(22.dp))
            }
        }
    }
}

@Composable
private fun ConfirmationOverlay(onDismiss: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)),
        contentAlignment = Alignment.Center) {
        Surface(
            shape = RoundedCornerShape(20.dp),
            color = Color.White,
            tonalElevation = 8.dp,
            modifier = Modifier.padding(40.dp).fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Box(
                    modifier = Modifier.size(80.dp).clip(CircleShape).background(Color(0xFF34C759)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(40.dp))
                }
                Text("Ajouté au widget !", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(
                    "Maintenez appuyé sur votre écran d'accueil pour ajouter le widget « Prochains passages »",
                    fontSize = 13.sp, color = Color(0xFF8E8E93),
                    textAlign = TextAlign.Center
                )
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.fillMaxWidth().height(46.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF007AFF)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Compris", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}
