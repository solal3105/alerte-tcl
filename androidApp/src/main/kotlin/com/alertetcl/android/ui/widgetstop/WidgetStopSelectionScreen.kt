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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.services.TransitStopService
import kotlinx.coroutines.launch

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
            modifier = Modifier.padding(16.dp),
            fontSize = 18.sp,
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
                    Text("Arrêts sélectionnés (${selectedStops.size})",
                        fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(top = 4.dp))
                }
                items(selectedStops, key = { "sel_${it.id}" }) { stop ->
                    StopRow(stop, isSelected = true) {
                        scope.launch { store.removeWidgetStop(stop.id) }
                    }
                }
                item {
                    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                }
            }
            if (filtered.isNotEmpty()) {
                item {
                    Text("Résultats (${filtered.size})",
                        fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(top = 4.dp))
                }
                items(filtered, key = { "search_${it.id}" }) { stop ->
                    val isSelected = stop.id in widgetStops
                    StopRow(stop, isSelected = isSelected) {
                        scope.launch {
                            if (isSelected) store.removeWidgetStop(stop.id)
                            else store.addWidgetStop(stop.id)
                        }
                    }
                }
            } else if (query.isNotBlank()) {
                item {
                    Text("Aucun arrêt trouvé", fontSize = 13.sp, color = Color.Gray,
                        modifier = Modifier.padding(16.dp))
                }
            }
        }
    }
}

@Composable
private fun StopRow(stop: TransitStop, isSelected: Boolean, onToggle: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = Color.White,
        modifier = Modifier.fillMaxWidth().clickable { onToggle() }
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                Icons.Filled.Place, null,
                tint = if (isSelected) Color(0xFF1976D2) else Color.Gray,
                modifier = Modifier.size(20.dp)
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(stop.nom, fontSize = 14.sp, fontWeight = FontWeight.Medium)
                Text(stop.commune, fontSize = 11.sp, color = Color.Gray)
            }
            if (isSelected) {
                IconButton(onClick = onToggle) {
                    Icon(Icons.Filled.Delete, "Retirer", tint = Color(0xFFE53935), modifier = Modifier.size(18.dp))
                }
            } else {
                Text("Ajouter", fontSize = 11.sp, color = Color(0xFF1976D2), fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
