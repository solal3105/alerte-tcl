package com.alertetcl.android.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.ui.theme.AlerteTCLTheme
import com.alertetcl.shared.models.TransitStop
import com.alertetcl.shared.services.TransitStopService

/**
 * Launched by the launcher when a widget is added to the home screen.
 * Wizard: Step 1 = pick a stop, Step 2 = pick a line + direction pair.
 */
@OptIn(ExperimentalMaterial3Api::class)
class WidgetConfigActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        // Default: canceled (user presses back without finishing)
        setResult(
            RESULT_CANCELED,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
        )

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContent {
            AlerteTCLTheme {
                WidgetConfigFlow(
                    onConfirm = { config ->
                        WidgetConfigStore.save(this, appWidgetId, config)
                        setResult(
                            RESULT_OK,
                            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                        )
                        finish()
                    },
                    onCancel = { finish() },
                )
            }
        }
    }
}

// ── Wizard state ──────────────────────────────────────────────────────────────

private sealed interface ConfigStep {
    data object SearchStop : ConfigStep
    data class PickLine(val stop: TransitStop) : ConfigStep
}

// ── Root flow ─────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WidgetConfigFlow(
    onConfirm: (WidgetConfig) -> Unit,
    onCancel: () -> Unit,
) {
    var step by remember { mutableStateOf<ConfigStep>(ConfigStep.SearchStop) }

    when (val s = step) {
        ConfigStep.SearchStop -> StopSearchStep(
            onStopSelected = { stop -> step = ConfigStep.PickLine(stop) },
            onCancel = onCancel,
        )
        is ConfigStep.PickLine -> LinePickStep(
            stop = s.stop,
            onConfirm = { lineName, direction ->
                onConfirm(
                    WidgetConfig(
                        stopId    = s.stop.id,
                        stopName  = s.stop.nom,
                        lineName  = lineName,
                        direction = direction,
                    )
                )
            },
            onBack = { step = ConfigStep.SearchStop },
        )
    }
}

// ── Step 1: Stop search ───────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StopSearchStep(
    onStopSelected: (TransitStop) -> Unit,
    onCancel: () -> Unit,
) {
    var query by remember { mutableStateOf("") }

    val allStops by produceState<List<TransitStop>>(emptyList()) {
        value = runCatching { TransitStopService.shared.fetchStops() }.getOrDefault(emptyList())
    }

    val filtered = remember(allStops, query) {
        val q = query.trim()
        if (q.isEmpty()) emptyList()
        else allStops.asSequence()
            .filter { it.nom.contains(q, ignoreCase = true) || it.commune.contains(q, ignoreCase = true) }
            .take(40)
            .toList()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Choisir un arrêt") },
                navigationIcon = {
                    IconButton(onClick = onCancel) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                placeholder = { Text("Nom d'arrêt ou commune…", fontSize = 13.sp) },
                singleLine = true,
            )

            if (allStops.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (filtered.isEmpty() && query.isNotBlank()) {
                Box(
                    modifier = Modifier.fillMaxSize().padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("Aucun arrêt trouvé", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(filtered, key = { it.id }) { stop ->
                        StopRow(stop = stop, onClick = { onStopSelected(stop) })
                    }
                }
            }
        }
    }
}

@Composable
private fun StopRow(stop: TransitStop, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        modifier = Modifier.fillMaxWidth().clickable { onClick() },
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.Place, null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(stop.nom, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(stop.commune, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
        }
    }
}

// ── Step 2: Line + direction ──────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LinePickStep(
    stop: TransitStop,
    onConfirm: (lineName: String, direction: String) -> Unit,
    onBack: () -> Unit,
) {
    // Fetch available (ligne, direction) pairs for the selected stop
    val linePairs by produceState<List<Pair<String, String>>?>(null) {
        value = runCatching {
            TransitStopService.shared
                .fetchPassagesForStop(stop.id)
                .map { it.ligne to it.direction }
                .distinctBy { it.first + "|" + it.second }
                .sortedWith(compareBy({ it.first }, { it.second }))
        }.getOrDefault(emptyList())
    }

    var selected by remember { mutableStateOf<Pair<String, String>?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Choisir une ligne", fontSize = 16.sp)
                        Text(stop.nom, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
            )
        },
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Button(
                    onClick = { selected?.let { onConfirm(it.first, it.second) } },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = selected != null,
                ) {
                    Text("Confirmer")
                }
            }
        },
    ) { innerPadding ->
        when (val pairs = linePairs) {
            null -> Box(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
            else -> if (pairs.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        "Aucune ligne disponible pour cet arrêt",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(
                        start = 12.dp, end = 12.dp,
                        top = innerPadding.calculateTopPadding() + 8.dp,
                        bottom = innerPadding.calculateBottomPadding() + 8.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(pairs, key = { it.first + "|" + it.second }) { pair ->
                        val isSelected = selected == pair
                        LinePairRow(
                            lineName  = pair.first,
                            direction = pair.second,
                            isSelected = isSelected,
                            onClick = { selected = pair },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun LinePairRow(
    lineName: String,
    direction: String,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val bgColor   = LineColorHelper.backgroundColor(lineName)
    val textColor = LineColorHelper.textColor(lineName)

    Surface(
        shape = RoundedCornerShape(14.dp),
        color = if (isSelected) MaterialTheme.colorScheme.primaryContainer
                else MaterialTheme.colorScheme.surface,
        tonalElevation = if (isSelected) 4.dp else 1.dp,
        modifier = Modifier.fillMaxWidth().clickable { onClick() },
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Line badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(bgColor)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    lineName,
                    color = textColor,
                    fontWeight = FontWeight.Black,
                    fontSize = 13.sp,
                )
            }

            Text(
                "→ $direction",
                modifier = Modifier.weight(1f),
                fontSize = 13.sp,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
