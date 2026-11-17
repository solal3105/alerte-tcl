package com.alertetcl.android.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.ui.about.AboutScreen
import com.alertetcl.android.ui.live.LiveMapScreen
import com.alertetcl.android.ui.onboarding.LocationPermissionView
import com.alertetcl.android.ui.onboarding.NotificationPermissionView
import com.alertetcl.android.ui.city.CityScreen
import com.alertetcl.android.ui.components.NewBadge
import com.alertetcl.android.ui.intro.IntroDialog
import com.alertetcl.shared.models.Intro
import com.alertetcl.shared.models.NewBadges
import com.alertetcl.shared.services.VelovForecastService
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private data class TabItem(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

private val tabs = listOf(
    TabItem("live",     "Transport", Icons.Filled.Tram),
    TabItem("ville",    "Autour de moi", Icons.Filled.NearMe),
    TabItem("about",    "Info",      Icons.Filled.Info),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlerteTCLApp(initialRoute: String? = null) {
    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val scope = rememberCoroutineScope()
    val onboardingDone by store.onboardingDone.collectAsState(initial = null)
    val introSeenRevision by store.introSeenRevision.collectAsState(initial = null)

    // Null = still loading from DataStore — don't show anything yet to avoid flash
    val seenRevision = introSeenRevision ?: return
    if (onboardingDone == null) return

    // Pastille « Nouveau » de la prévision Vélo'v, sur l'onglet et sur la tuile : le modèle se charge dès
    // le lancement, et sa disponibilité est relue à chaque retour au premier plan.
    val velovForecastOpened by store.velovForecastBadgeOpened.collectAsState(initial = true)
    var velovForecastAvailable by remember { mutableStateOf(false) }
    var velovForecastCheckedAtMs by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) { VelovForecastService.shared.warmUp() }
    LifecycleResumeEffect(Unit) {
        val check = scope.launch {
            val now = System.currentTimeMillis()
            velovForecastAvailable = isVelovForecastAvailable(now)
            velovForecastCheckedAtMs = now
        }
        onPauseOrDispose { check.cancel() }
    }
    val velovForecastNew = NewBadges.showsVelovForecast(velovForecastOpened, velovForecastAvailable, velovForecastCheckedAtMs)

    // L'intro passe avant les autorisations : elle dit à quoi servent la position et les alertes. Elle
    // attend la première lecture de la prévision Vélo'v, dont les pages ne paraissent qu'avec un modèle.
    var showIntro by remember { mutableStateOf(false) }
    var introForecast by remember { mutableStateOf(false) }
    var showLocationSheet by remember { mutableStateOf(false) }
    var showNotifSheet by remember { mutableStateOf(false) }
    val forecastChecked = velovForecastCheckedAtMs > 0
    LaunchedEffect(forecastChecked) {
        if (!forecastChecked) return@LaunchedEffect
        introForecast = velovForecastAvailable
        if (Intro.shouldShow(seenRevision, introForecast)) showIntro = true
        else if (onboardingDone == false) showLocationSheet = true
    }

    val nav = rememberNavController()
    val backStackEntry = nav.currentBackStackEntryAsState().value
    val currentRoute = backStackEntry?.destination?.route

    // Deep-link: switch tab on incoming route. En démo « velov… » ou « ville », l'onglet « Autour de moi » s'ouvre de lui-même.
    LaunchedEffect(initialRoute) {
        val target = initialRoute
            ?: com.alertetcl.shared.util.DemoShowcase.current?.let { demo ->
                when {
                    demo.startsWith("velov") || demo == "ville" -> "ville"
                    demo == "info" -> "about"
                    else -> null
                }
            }
            ?: return@LaunchedEffect
        if (tabs.any { it.route == target }) {
            nav.navigate(target) {
                launchSingleTop = true
                popUpTo(nav.graph.startDestinationId) { saveState = true }
            }
        }
    }

    Scaffold(
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                NavigationBar(
                    modifier = Modifier
                        .fillMaxWidth()
                        .shadow(elevation = 6.dp, shape = RoundedCornerShape(28.dp))
                        .clip(RoundedCornerShape(28.dp)),
                    windowInsets = WindowInsets(0),
                ) {
                    tabs.forEach { tab ->
                        NavigationBarItem(
                            selected = currentRoute == tab.route ||
                                       backStackEntry?.destination?.hierarchy?.any { it.route == tab.route } == true,
                            onClick = {
                                nav.navigate(tab.route) {
                                    launchSingleTop = true
                                    restoreState = true
                                    popUpTo(nav.graph.startDestinationId) { saveState = true }
                                }
                            },
                            icon = {
                                BadgedBox(badge = { if (tab.route == "ville" && velovForecastNew) NewBadge() }) {
                                    Icon(tab.icon, contentDescription = tab.label)
                                }
                            },
                            label = { Text(tab.label) }
                        )
                    }
                }
            }
        }
    ) { _ ->
        NavHost(
            navController = nav,
            startDestination = "live",
            modifier = Modifier.fillMaxSize()
        ) {
            composable("live")    { LiveMapScreen() }
            composable("ville") { CityScreen(velovForecastNew) }
            composable("about")   { AboutScreen(velovForecastAvailable) }
        }
    }

    if (showIntro) {
        IntroDialog(atLaunch = true, seenRevision = seenRevision, forecastAvailable = introForecast, onFinish = {
            scope.launch { store.setIntroSeen(maxOf(seenRevision, Intro.reachedRevision(introForecast))) }
            showIntro = false
            if (onboardingDone == false) showLocationSheet = true
        })
    }

    if (showLocationSheet) {
        ModalBottomSheet(
            onDismissRequest = {
                showLocationSheet = false
                showNotifSheet = true
                scope.launch { store.setOnboardingDone() }
            },
            sheetState = rememberModalBottomSheetState(),
            contentWindowInsets = { WindowInsets.systemBars }
        ) {
            LocationPermissionView(onDismiss = {
                showLocationSheet = false
                showNotifSheet = true
                scope.launch { store.setOnboardingDone() }
            })
        }
    }

    if (showNotifSheet) {
        ModalBottomSheet(
            onDismissRequest = { showNotifSheet = false },
            sheetState = rememberModalBottomSheetState(),
            contentWindowInsets = { WindowInsets.systemBars }
        ) {
            NotificationPermissionView(onDismiss = { showNotifSheet = false })
        }
    }
}

/** Vrai s'il y a une prévision Vélo'v à montrer à [nowMs] ; faux si le modèle enregistré ne peut pas être lu. */
private suspend fun isVelovForecastAvailable(nowMs: Long): Boolean = try {
    VelovForecastService.shared.isAvailable(nowMs)
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    false
}
