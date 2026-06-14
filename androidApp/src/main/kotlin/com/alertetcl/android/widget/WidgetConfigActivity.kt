package com.alertetcl.android.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.data.WidgetSelection
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.android.ui.theme.AlerteTCLTheme
import com.alertetcl.shared.models.LineColors

/**
 * Base config activity for all widget types.
 *
 * Commits the widget (RESULT_OK) BEFORE triggering the Glance update.
 * Glance's AppWidgetSession calls getAppWidgetInfo() internally, which returns null
 * for pending (uncommitted) widgets — causing the update to be silently dropped.
 */
@OptIn(ExperimentalMaterial3Api::class)
open class WidgetConfigActivity : ComponentActivity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.extras?.getInt(
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
                        // Commit the widget BEFORE updating.
                        // Glance's AppWidgetSession calls getAppWidgetInfo() which returns
                        // null for pending (uncommitted) widgets — the update is silently
                        // dropped, leaving the widget stuck on "Appuyer pour configurer"
                        // until the next periodic WorkManager refresh (~15 min).
                        setResult(
                            RESULT_OK,
                            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                        )
                        finish()
                        // Trigger an immediate one-time refresh. WorkManager fires after
                        // the launcher processes RESULT_OK, so the widget is committed
                        // by the time the update runs.
                        WorkManager.getInstance(applicationContext)
                            .enqueue(OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build())
                    },
                    onCancel = { finish() },
                )
            }
        }
    }
}

/** Config activity for [NextDeparturesGlanceWidget]. */
class NextDeparturesWidgetConfigActivity : WidgetConfigActivity()

/** Config activity for [TCLBoardGlanceWidget]. */
class TCLBoardWidgetConfigActivity : WidgetConfigActivity()

// ── Config flow ───────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WidgetConfigFlow(
    onConfirm: (WidgetConfig) -> Unit,
    onCancel: () -> Unit,
) {
    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val selections by store.widgetSelections.collectAsState(initial = null)

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
        when (val list = selections) {
            null -> Box(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator() }

            else -> if (list.isEmpty()) {
                EmptySelectionsContent(modifier = Modifier.fillMaxSize().padding(innerPadding))
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(
                        start = 12.dp, end = 12.dp,
                        top = innerPadding.calculateTopPadding() + 8.dp,
                        bottom = innerPadding.calculateBottomPadding() + 8.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(list, key = { it.id }) { sel ->
                        SelectionRow(sel) {
                            onConfirm(
                                WidgetConfig(
                                    stopId          = sel.stopId,
                                    stopName        = sel.stopName,
                                    lineName        = sel.lineName,
                                    direction       = sel.direction,
                                    destinationName = sel.destinationName,
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptySelectionsContent(modifier: Modifier = Modifier) {
    Box(modifier = modifier.padding(32.dp), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Aucun arrêt configuré",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "Ouvre l'app → zoome sur un arrêt sur la carte → appuie dessus → « Ajouter au widget »",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun SelectionRow(sel: WidgetSelection, onClick: () -> Unit) {
    val bgColor   = colorFromHex(LineColors.backgroundHex(sel.lineName))
    val textColor = colorFromHex(LineColors.textHex(sel.lineName))

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
                    .clip(RoundedCornerShape(50))
                    .background(bgColor)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    sel.lineName,
                    color = textColor,
                    fontWeight = FontWeight.Black,
                    fontSize = 13.sp,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(sel.stopName, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("→ ${sel.destinationName.ifBlank { sel.direction }}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

