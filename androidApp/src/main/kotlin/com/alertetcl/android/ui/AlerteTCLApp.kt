package com.alertetcl.android.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
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
import com.alertetcl.android.ui.parking.ParkingScreen
import com.alertetcl.android.ui.travaux.TravauxScreen
import kotlinx.coroutines.launch

private data class TabItem(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

private val tabs = listOf(
    TabItem("live",     "Transport", Icons.Filled.Tram),
    TabItem("travaux",  "Travaux",   Icons.Filled.Build),
    TabItem("parking",  "Parkings",  Icons.Filled.DirectionsCar),
    TabItem("about",    "Info",      Icons.Filled.Info),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlerteTCLApp(initialRoute: String? = null) {
    val context = LocalContext.current
    val store = remember { FavoritesStore(context) }
    val scope = rememberCoroutineScope()
    val onboardingDone by store.onboardingDone.collectAsState(initial = null)

    // Null = still loading from DataStore — don't show anything yet to avoid flash
    if (onboardingDone == null) return

    var showLocationSheet by remember { mutableStateOf(onboardingDone == false) }
    var showNotifSheet by remember { mutableStateOf(false) }

    val nav = rememberNavController()
    val backStackEntry = nav.currentBackStackEntryAsState().value
    val currentRoute = backStackEntry?.destination?.route

    // Deep-link: switch tab on incoming route
    androidx.compose.runtime.LaunchedEffect(initialRoute) {
        val target = initialRoute ?: return@LaunchedEffect
        if (tabs.any { it.route == target }) {
            nav.navigate(target) {
                launchSingleTop = true
                popUpTo(nav.graph.startDestinationId) { saveState = true }
            }
        }
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
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
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = "live",
            modifier = Modifier.padding(bottom = padding.calculateBottomPadding())
        ) {
            composable("live")    { LiveMapScreen() }
            composable("travaux") { TravauxScreen() }
            composable("parking") { ParkingScreen() }
            composable("about")   { AboutScreen() }
        }
    }

    if (showLocationSheet) {
        ModalBottomSheet(
            onDismissRequest = {
                showLocationSheet = false
                showNotifSheet = true
                scope.launch { store.setOnboardingDone() }
            },
            sheetState = rememberModalBottomSheetState()
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
            sheetState = rememberModalBottomSheetState()
        ) {
            NotificationPermissionView(onDismiss = { showNotifSheet = false })
        }
    }
}
